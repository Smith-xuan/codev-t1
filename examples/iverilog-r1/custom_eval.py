
import os
import json
import logging
import asyncio
import subprocess
import shutil
from typing import Any, List, Dict
from argparse import Namespace
from datetime import datetime

import ray
from tqdm import tqdm

from slime.rollout.base_types import RolloutFnEvalOutput
from slime.utils.types import Sample
from slime.rollout.sglang_rollout import generate, GenerateState, generate_and_rm_group

# Helper to ensure we can import from local directory if needed
import sys
sys.path.append(os.path.dirname(__file__))
# Import the generate function from generate_with_iverilog to ensure we use the same generation logic (multi-turn)
from generate_with_iverilog import generate as custom_generate
from verilog_utils import extract_verilog_from_generation

logger = logging.getLogger(__name__)

from slime.utils.async_utils import run

def custom_eval_rollout(
    args: Namespace, rollout_id: int, data_source: Any, evaluation: bool = True
) -> RolloutFnEvalOutput:
    """
    Custom evaluation function that runs the benchmark on a specific JSONL file.
    """
    output, _ = run(_custom_eval_rollout_async(args, rollout_id))
    return output

async def _custom_eval_rollout_async(
    args: Namespace, rollout_id: int
) -> tuple[RolloutFnEvalOutput, list[list[Sample]]]:
    logger.info(f"Starting custom benchmark evaluation for rollout {rollout_id}")
    
    # 1. Configuration
    # Hardcoded path as requested
    TEST_DATA_PATH = "/workspace/S/shiwenxuan/codev_test/benchmark/CVDP/data/test/cvdp-v1.0.2-codegen-nonagentic-nc.jsonl.tmp"
    CODEV_TEST_ROOT = "/workspace/S/shiwenxuan/codev_test"
    
    # Check if test file exists
    if not os.path.exists(TEST_DATA_PATH):
        logger.error(f"Test data file not found: {TEST_DATA_PATH}")
        return RolloutFnEvalOutput(data={}), []
        
    # 2. Load the test data
    samples = []
    ids = []
    with open(TEST_DATA_PATH, 'r') as f:
        for line in f:
            if not line.strip():
                continue
            item = json.loads(line)
            # Create a Sample object
            # We need to adapt the fields. 
            # prompt -> prompt
            # id -> metadata
            sample = Sample(
                prompt=item["prompt"],
                index=len(samples),
                metadata={"id": item["id"]}
            )
            samples.append(sample)
            ids.append(item["id"])
            
    logger.info(f"Loaded {len(samples)} samples from {TEST_DATA_PATH}")
    
    # 3. Generate responses
    # We reuse the logic from generate_with_iverilog.py via generate_and_rm_group or manual loop
    # Since we want to use the custom multi-turn generation, we should use custom_generate
    
    # We need to patch args to use custom_generate if not already set, 
    # but here we are calling the function directly.
    # However, generate_with_iverilog.py's generate function signature matches what sglang_rollout expects.
    
    # We can use sglang_rollout.generate_rollout_async logic but adapted.
    
    state = GenerateState(args)
    # We need to set sampling params based on args or hardcode for eval
    sampling_params = state.sampling_params.copy()
    # For evaluation, we might want deterministic results
    if args.rollout_temperature > 0:
        sampling_params["temperature"] = args.rollout_temperature
    
    # Helper to run generation in parallel
    async def generate_single(sample):
        # We call the custom_generate function from generate_with_iverilog.py
        # This function handles the multi-turn logic
        return await custom_generate(args, sample, sampling_params)

    # Run generation
    results = []
    # Process in batches to control concurrency
    batch_size = args.rollout_batch_size
    
    logger.info(f"Generating responses for {len(samples)} samples with batch size {batch_size}")
    
    for i in range(0, len(samples), batch_size):
        batch = samples[i:i+batch_size]
        tasks = [generate_single(s) for s in batch]
        batch_results = await asyncio.gather(*tasks)
        results.extend(batch_results)
        
    logger.info("Generation completed.")
    
    # 4. Prepare for benchmark execution
    # We need to dump the results to a JSONL file in the format expected by extract_verilog.py
    # Format: {"task_id": "...", "completion": "..."} or {"task_id": "...", "response": [{"content": "..."}]}
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    eval_name = f"eval_rollout_{rollout_id}_{timestamp}"
    
    # Directory for temporary files
    # Using the path expected by test_cvdp_custom.sh logic structure or just our own
    # We will use CODEV_TEST_ROOT/results/test/cvdp-v1.0.2/codegen/{eval_name}
    result_dir = os.path.join(CODEV_TEST_ROOT, "results", "test", "cvdp-v1.0.2", "codegen", eval_name)
    os.makedirs(result_dir, exist_ok=True)
    
    raw_jsonl_path = os.path.join(result_dir, "raw.jsonl")
    
    with open(raw_jsonl_path, 'w') as f:
        for sample in results:
            # Extract code using the same logic as reward function
            extracted_code = extract_verilog_from_generation(
                sample.prompt + sample.response, 
                require_complete=True, 
                keep_testbench=False
            )
            
            # Wrap in markdown to ensure extract_verilog.py works correctly as it expects markdown
            completion_content = f"```verilog\n{extracted_code}\n```" if extracted_code else ""
            
            entry = {
                "task_id": sample.metadata["id"],
                "completion": completion_content
            }
            f.write(json.dumps(entry) + "\n")
            
    logger.info(f"Saved raw outputs to {raw_jsonl_path}")
    
    # 5. Run the benchmark scripts
    # We replicate the logic of test_cvdp_custom.sh
    
    env = os.environ.copy()
    env["PYTHONPATH"] = f"{CODEV_TEST_ROOT}:{env.get('PYTHONPATH', '')}"
    
    final_jsonl_path = os.path.join(result_dir, "final.jsonl")
    
    try:
        # Step 1: Extract verilog
        # python scripts/data_process/extract_verilog.py -i "$INPUT_FILE" -o "$CODE_FINAL"
        # Since we already extracted code, we can skip this step or run it as identity check.
        # But user requested running the script.
        # extract_verilog.py expects code in "completion" or "response".
        # If "completion" contains raw code, extract_verilog.py might be confused if it expects markdown?
        # Let's wrap it in markdown if it's not empty, to be safe for extract_verilog.py
        
        # Re-write raw.jsonl with markdown wrapper if needed
        # Or better: Just write the extracted code. extract_verilog_code usually handles raw code too.
        # Let's assume extract_verilog.py is robust.
        
        logger.info("Running extract_verilog.py...")
        cmd_extract = [
            "python", 
            "scripts/data_process/extract_verilog.py",
            "-i", raw_jsonl_path,
            "-o", final_jsonl_path
        ]
        subprocess.run(cmd_extract, cwd=CODEV_TEST_ROOT, env=env, check=True)
        
        # Step 2: Fix IDs using jq logic (simulated in python to avoid jq dependency/shell issues)
        # jq -c '.id = .task_id | del(.task_id)' $CODE_FINAL
        logger.info("Fixing JSONL format...")
        temp_final_path = final_jsonl_path + ".tmp"
        with open(final_jsonl_path, 'r') as fin, open(temp_final_path, 'w') as fout:
            for line in fin:
                if not line.strip(): continue
                data = json.loads(line)
                if "task_id" in data:
                    data["id"] = data["task_id"]
                    del data["task_id"]
                fout.write(json.dumps(data) + "\n")
        shutil.move(temp_final_path, final_jsonl_path)
        
        # Step 3: Preprocess
        # python scripts/custom_test/cvdp_preprocess.py ...
        logger.info("Running cvdp_preprocess.py...")
        custom_test_dir = os.path.join(result_dir, "custom_test")
        cmd_preprocess = [
            "python",
            "scripts/custom_test/cvdp_preprocess.py",
            "--jsonl", "benchmark/CVDP/data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial_cocotb2.jsonl",
            "--outdir", custom_test_dir
        ]
        subprocess.run(cmd_preprocess, cwd=CODEV_TEST_ROOT, env=env, check=True)
        
        # Step 4: Run test
        # python scripts/custom_test/cvdp_run_test.py ...
        logger.info("Running cvdp_run_test.py...")
        cmd_run_test = [
            "python",
            "scripts/custom_test/cvdp_run_test.py",
            "--jsonl", final_jsonl_path,
            "--workspace", custom_test_dir,
            "--workers", "16"
        ]
        # We capture output to parse or read the report file
        subprocess.run(cmd_run_test, cwd=CODEV_TEST_ROOT, env=env, check=True)
        
        # 6. Parse results
        report_path = os.path.join(custom_test_dir, "multi_sample_report.txt")
        pass_rate_sum = 0.0
        
        if os.path.exists(report_path):
            with open(report_path, 'r') as f:
                for line in f:
                    # Line format: | qid | cid | Pass Count: p/n
                    if "Pass Count:" in line:
                        parts = line.split("Pass Count:")
                        if len(parts) > 1:
                            counts = parts[1].strip().split("/")
                            if len(counts) == 2:
                                p = int(counts[0])
                                n = int(counts[1])
                                if n > 0:
                                    pass_rate_sum += p / n
        else:
            logger.warning(f"Report file not found: {report_path}")
            
        # Use total samples count as denominator to account for missing/failed executions
        total_samples = len(samples)
        score = 0.0
        if total_samples > 0:
            score = pass_rate_sum / total_samples
        
        logger.info(f"Benchmark score: {score:.4f} (sum_pass_rates={pass_rate_sum:.2f}/{total_samples})")
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Benchmark execution failed: {e}")
        score = 0.0
    except Exception as e:
        logger.error(f"Unexpected error during benchmark evaluation: {e}")
        score = 0.0
        
    # 7. Return results
    # Slime expects dict[str, dict[str, list]]
    # We return a single metric "cvdp_pass_rate"
    # To fit the format, we assign the score to all samples
    
    dataset_name = "cvdp_benchmark"
    eval_results = {
        dataset_name: {
            "rewards": [score] * len(results), # Assign the global score to each sample for logging
            "truncated": [False] * len(results),
            "samples": results
        }
    }
    
    return RolloutFnEvalOutput(data=eval_results), []


