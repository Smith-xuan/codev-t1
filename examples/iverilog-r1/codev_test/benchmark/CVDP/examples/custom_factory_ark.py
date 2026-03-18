# custom_factory_ark.py
# SPDX-License-Identifier: Apache-2.0

import json
import logging
import os
import sys
from typing import Any, Dict, List, Optional

# Add the current directory to path so we can import from the same directory
current_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if current_dir not in sys.path:
    # sys.path.append(current_dir)
    sys.path.insert(0, current_dir)

from src.llm_lib.model_factory import ModelFactory
from src.config_manager import config

# pip install volcengine-python-sdk[ark]
from volcenginesdkarkruntime import Ark

logging.basicConfig(level=logging.INFO)


def _env_bool(name: str, default: bool = False) -> bool:
    v = os.environ.get(name)
    if v is None:
        return default
    return v.strip().lower() in ("1", "true", "yes", "y", "on")


def _load_model_mapping() -> Dict[str, Dict[str, Optional[str]]]:
    """
    Read mapping from env ARK_MODEL_MAPPING (JSON string).
    Fallback to a minimal empty mapping.
    """
    raw = os.environ.get("ARK_MODEL_MAPPING", "").strip()
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        if not isinstance(data, dict):
            raise ValueError("ARK_MODEL_MAPPING must be a JSON object")
        return data
    except Exception as e:
        raise ValueError(f"Invalid ARK_MODEL_MAPPING JSON: {e}")


class ArkClientProvider:
    """
    Lazily create a single Ark client (thread-safe enough for typical usage because SDK handles pooling).
    """
    def __init__(self):
        self.api_key = os.environ.get("ARK_API_KEY")
        self.base_url = os.environ.get("ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3")
        self.timeout = int(os.environ.get("ARK_TIMEOUT", "3600"))

        if not self.api_key:
            raise ValueError("ARK_API_KEY is not set")

        self.client = Ark(
            api_key=self.api_key,
            base_url=self.base_url,
            timeout=self.timeout,
        )


def get_model_id(model_mapping: Dict[str, Dict[str, Optional[str]]], model_name: str, use_batch: bool) -> str:
    """
    model_name: short name like ds-v3.2 / kimi
    """
    if model_name not in model_mapping:
        raise ValueError(
            f"Unsupported ARK model short name: {model_name}. "
            f"Available: {list(model_mapping.keys())}"
        )
    model_cfg = model_mapping[model_name]
    model_id = model_cfg.get("batch") if use_batch else model_cfg.get("non_batch")
    if not model_id:
        raise ValueError(f"Model {model_name} does not have {'batch' if use_batch else 'non-batch'} endpoint id")
    return model_id


class ArkChat_Instance:
    """
    Main model instance backed by ARK.
    Tries to be compatible with common LLM instance interfaces:
      - prompt(...)
      - chat(messages, ...)
      - __call__(...)
    """

    def __init__(
        self,
        context: Any = None,
        key: Optional[str] = None,   # kept for compatibility; ARK uses ARK_API_KEY env
        model: Optional[str] = None,
        use_batch: Optional[bool] = None,
        enable_thinking: Optional[bool] = None,
        client_provider: Optional[ArkClientProvider] = None,
    ):
        self.context = context
        self.debug = False

        self.model_mapping = _load_model_mapping()

        # default model short name
        default_short = os.environ.get("ARK_DEFAULT_MODEL") or config.get("DEFAULT_MODEL") or "ds-v3.2"
        self.model_short = model or default_short

        self.use_batch = _env_bool("ARK_USE_BATCH", False) if use_batch is None else use_batch
        self.enable_thinking = _env_bool("ARK_ENABLE_THINKING", False) if enable_thinking is None else enable_thinking

        self.client_provider = client_provider or ArkClientProvider()
        self.client = self.client_provider.client

    def set_debug(self, debug: bool = True) -> None:
        self.debug = debug

    def chat(self, messages: List[Dict[str, str]], temperature: float = 0.1, timeout: Optional[int] = None, **kwargs) -> str:
        model_id = get_model_id(self.model_mapping, self.model_short, self.use_batch)

        if self.use_batch:
            resp = self.client.batch_chat.completions.create(
                model=model_id,
                messages=messages,
            )
        else:
            extra_body = {}
            if self.enable_thinking:
                extra_body["thinking"] = {"type": "enabled"}

            resp = self.client.chat.completions.create(
                model=model_id,
                messages=messages,
                temperature=temperature,
                timeout=timeout,
                extra_body=extra_body if extra_body else None,
            )

        choice = resp.choices[0]
        # 兼容 reasoning_content
        if hasattr(choice.message, "reasoning_content") and choice.message.reasoning_content:
            return f"<think>{choice.message.reasoning_content}</think>\n\n<answer>{choice.message.content}</answer>"
        return choice.message.content

    def prompt(
        self,
        prompt: str,
        schema=None,
        prompt_log: str = "",
        files: Optional[List[str]] = None,
        timeout: Optional[int] = None,
        category=None,
        **kwargs,
    ) -> str:
        """
        Compatibility wrapper similar to OpenAI_Instance.prompt signature.
        Many harnesses call .prompt() and expect a string.
        """
        messages = [{"role": "user", "content": prompt}]
        return self.chat(messages=messages, timeout=timeout, **kwargs)

    def __call__(self, *args, **kwargs) -> str:
        # Some frameworks call the instance directly
        if args and isinstance(args[0], list):
            return self.chat(args[0], **kwargs)
        if args and isinstance(args[0], str):
            return self.prompt(args[0], **kwargs)
        raise TypeError("ArkChat_Instance called with unsupported arguments")


class ArkSubjectiveScoreModel_Instance:
    """
    ARK-based replacement for sbj_score_model.SubjectiveScoreModel_Instance.
    Keeps the same public API: subjective_score(response, reference, problem_prompt) -> float
    """

    def __init__(
        self,
        context: Any = None,               # not used
        key: Optional[str] = None,         # kept for compatibility
        model: Optional[str] = None,       # short name for judge model
        use_batch: Optional[bool] = None,
        client_provider: Optional[ArkClientProvider] = None,
    ):
        self.debug = False
        self.model_timeout = config.get("MODEL_TIMEOUT", 60)
        if not isinstance(self.model_timeout, int):
            self.model_timeout = 60

        self.model_mapping = _load_model_mapping()

        judge_short = os.environ.get("ARK_JUDGE_MODEL") or os.environ.get("ARK_DEFAULT_MODEL") or "ds-v3.2"
        self.model_short = model or judge_short

        self.use_batch = _env_bool("ARK_JUDGE_USE_BATCH", False) if use_batch is None else use_batch

        self.client_provider = client_provider or ArkClientProvider()
        self.client = self.client_provider.client

        logging.info(f"Created ARK Subjective Scoring Model. judge_model={self.model_short}, batch={self.use_batch}")

    def set_debug(self, debug: bool = True) -> None:
        self.debug = debug

    def _ark_chat(self, messages: List[Dict[str, str]]) -> str:
        model_id = get_model_id(self.model_mapping, self.model_short, self.use_batch)

        if self.use_batch:
            resp = self.client.batch_chat.completions.create(
                model=model_id,
                messages=messages,
            )
        else:
            resp = self.client.chat.completions.create(
                model=model_id,
                messages=messages,
                temperature=0.1,
                timeout=self.model_timeout,
            )

        return resp.choices[0].message.content.strip()

    def subjective_score(self, response: str, reference: str, problem_prompt: str = "") -> float:
        
        system_prompt = """You are an expert at evaluating the quality of responses compared to reference solutions.
Your task is to score how well a candidate response matches the reference solution on a scale from 0.0 to 1.0,
where 0.0 means no match at all and 1.0 means a perfect match.

Important: You should evaluate the responses ONLY in relation to the original problem or question that was asked.
Focus on how well each response addresses the specific requirements and needs of the original problem prompt.

Look for the following aspects when scoring:
1. Relevance - how well does each response address the specific question or problem posed?
2. Semantic similarity - do the responses convey the same meaning in the context of the original problem?
3. Content completeness - does the candidate response include all the necessary information required by the prompt?
4. Correctness - is the candidate response accurate and correct with respect to what was asked?
5. Style and format consistency - does the candidate response follow the same style as the reference?

You must be critical and objective in your assessment. Provide a numeric score as a floating point number.

The response should be in the form of a JSON object with the following fields:
{
    "score": <float>,
    "reasoning": <string>
}
"""
        
        # Use custom prompt if provided, otherwise use default prompt with problem context
        user_prompt = f"""Please evaluate the following candidate response against the reference solution.
Score the match on a scale from 0.0 to 1.0, where 0.0 means no match at all and 1.0 means a perfect match.

Original Problem/Question:
```
{problem_prompt}
```

Reference Solution:
```
{reference}
```

Candidate Response:
```
{response}
```

Important: Evaluate the candidate response ONLY on how well it addresses the original problem compared to the reference solution. 
Ignore aspects that aren't relevant to the original problem.

Provide your score as a single number from 0.0 to 1.0.

An example response is:
{{
    "score": 0.85,
    "reasoning": "The candidate response addresses the original problem well, but lacks some depth in the analysis."
}}
"""

        max_retries = 5
        for attempt in range(max_retries):
            text = self._ark_chat(
                [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ]
            )

            # Try parse JSON (robust against code fences)
            try:
                if "```json" in text:
                    json_content = text.split("```json")[1].rsplit("```", 1)[0].strip()
                elif "```" in text:
                    json_content = text.split("```")[1].rsplit("```", 1)[0].strip()
                else:
                    json_content = text

                obj = json.loads(json_content)
                if "score" in obj:
                    score = float(obj["score"])
                    return max(0.0, min(1.0, score))
            except Exception:
                if self.debug:
                    logging.exception(f"Failed to parse judge JSON (attempt {attempt+1}/{max_retries}). Raw: {text[:2000]}")
                continue

        return 0.0


class CustomModelFactory(ModelFactory):
    """
    Custom model factory that routes certain model names to ARK.
    """

    def __init__(self):
        super().__init__()

        # One shared Ark client for all instances
        self._ark_provider = ArkClientProvider()

        # Register sbj_score model
        self.model_types["sbj_score"] = self._create_ark_sbj_score_instance

        # Register ARK model prefix routing.
        # Usage: -m ark-ds-v3.2  OR -m ark-kimi
        self.model_types["ark"] = self._create_ark_chat_instance

        logging.info("CustomModelFactory(ARK) initialized: supports 'ark-*' and 'sbj_score'")

    def _create_ark_chat_instance(self, model_name: str, context: Any, key: Optional[str], **kwargs) -> Any:
        """
        model_name could be:
          - "ark" (rare)
          - "ark-ds-v3.2"
          - "ark-kimi"
        We'll parse "ark-" prefix.
        """
        short = model_name
        if model_name.startswith("ark-"):
            short = model_name[len("ark-"):]

        # allow override via kwargs
        use_batch = kwargs.get("use_batch", None)
        enable_thinking = kwargs.get("enable_thinking", None)

        return ArkChat_Instance(
            context=context,
            key=key,
            model=short,
            use_batch=use_batch,
            enable_thinking=enable_thinking,
            client_provider=self._ark_provider,
        )

    def _create_ark_sbj_score_instance(self, model_name: str, context: Any, key: Optional[str], **kwargs) -> Any:
        judge_short = kwargs.get("judge_model", None)  # optional override
        use_batch = kwargs.get("use_batch", None)
        return ArkSubjectiveScoreModel_Instance(
            context=context,
            key=key,
            model=judge_short,
            use_batch=use_batch,
            client_provider=self._ark_provider,
        )



if __name__ == "__main__":
    print("=" * 80)
    print("[TEST 1] Direct usage of ArkSubjectiveScoreModel_Instance")
    print("=" * 80)

    try:
        scorer = ArkSubjectiveScoreModel_Instance()

        problem = "Write a function to calculate the factorial of a number."
        reference = (
            "def factorial(n):\n"
            "    if n == 0 or n == 1:\n"
            "        return 1\n"
            "    else:\n"
            "        return n * factorial(n-1)\n"
        )
        response = (
            "def factorial(n):\n"
            "    result = 1\n"
            "    for i in range(1, n+1):\n"
            "        result *= i\n"
            "    return result\n"
        )

        score = scorer.subjective_score(response, reference, problem)
        print(f"[OK] Subjective score returned: {score}")

    except Exception as e:
        print("[ERROR] sbj_score direct usage failed")
        print(e)

    print("\n" + "=" * 80)
    print("[TEST 2] CustomModelFactory create_model")
    print("=" * 80)

    try:
        factory = CustomModelFactory()

        # ---- Test ARK chat model ----
        model_name = "ark-ds-v3.2"
        ark_model = factory.create_model(
            model_name=model_name,
            context="Test context for ARK model"
        )

        print(f"[OK] Created ARK model for '{model_name}': {type(ark_model).__name__}")

        reply = ark_model.prompt(
            prompt="Generate a simple hello world program in Python.",
            timeout=60,
        )
        print("[OK] ARK model response:")
        print(reply)

        # ---- Test subjective scoring model via factory ----
        sbj_model = factory.create_model(
            model_name="sbj_score",
            context="Test context for scoring"
        )

        print(f"[OK] Created sbj_score model: {type(sbj_model).__name__}")

        score = sbj_model.subjective_score(
            "print('hello world')",
            "print('hello world')",
            "Print hello world in Python"
        )
        print(f"[OK] Subjective score via factory: {score}")

    except Exception as e:
        print("[ERROR] CustomModelFactory test failed")
        print(e)