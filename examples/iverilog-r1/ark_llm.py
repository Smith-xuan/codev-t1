"""
火山引擎 Ark + DeepSeek 接入（与 LLaMA-Factory/deduplicate/generate_instruction_for_non_r1.py 对齐）。

依赖: pip install volcenginesdkarkruntime
"""

from __future__ import annotations

import os
from typing import Any

# 与 generate_instruction_for_non_r1.MODEL_MAPPING 一致
MODEL_MAPPING = {
    "ds-v3": {"non_batch": "ep-20250925035907-8jnbt", "batch": None},
    "ds-v3.1": {"non_batch": "ep-20250925035746-ghz7r", "batch": "ep-bi-20251031022241-b4dvh"},
    "ds-v3.2": {"non_batch": "ep-20251207182251-w99km", "batch": "ep-bi-20251211182619-bt7nh"},
    "ds-r1": {"non_batch": "ep-20251031003805-f9mrq", "batch": "ep-bi-20251031022035-xn8pl"},
    "kimi": {"non_batch": "ep-20250924164936-hlrkm", "batch": "ep-bi-20251031022206-6w8mt"},
}


def get_model_id(model_name: str, use_batch: bool) -> str:
    if model_name not in MODEL_MAPPING:
        raise ValueError(f"不支持的模型: {model_name}，可选: {list(MODEL_MAPPING.keys())}")
    model_id = MODEL_MAPPING[model_name]["batch" if use_batch else "non_batch"]
    if model_id is None:
        raise ValueError(f"模型 {model_name} 没有 {'batch' if use_batch else 'non-batch'} 版本")
    return model_id


def build_ark_client(
    api_key: str | None = None,
    base_url: str | None = None,
):
    from volcenginesdkarkruntime import Ark

    key = (
        api_key
        or os.environ.get("ARK_API_KEY")
        or os.environ.get("VOLCENGINE_API_KEY")
        or os.environ.get("DEEPSEEK_API_KEY")
    )
    if not key:
        raise RuntimeError(
            "未设置 Ark API Key，请设置 ARK_API_KEY（或 VOLCENGINE_API_KEY / DEEPSEEK_API_KEY）"
        )
    url = base_url or os.environ.get(
        "ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3"
    )
    timeout = int(os.environ.get("ARK_TIMEOUT", str(3600 * 24)))
    return Ark(api_key=key, base_url=url, timeout=timeout)


def ask_llm(
    client: Any,
    messages: list,
    model_name: str = "ds-v3.2",
    use_batch: bool = False,
    enable_thinking: bool = True,
    **create_kwargs: Any,
):
    """与 generate_instruction_for_non_r1.ask_llm 一致。"""
    model_id = get_model_id(model_name, use_batch)
    if use_batch:
        return client.batch_chat.completions.create(
            model=model_id, messages=messages, **create_kwargs
        )
    kwargs: dict[str, Any] = {"model": model_id, "messages": messages, **create_kwargs}
    if enable_thinking:
        kwargs["extra_body"] = {"thinking": {"type": "enabled"}}
    return client.chat.completions.create(**kwargs)
