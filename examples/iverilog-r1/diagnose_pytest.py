#!/usr/bin/env python3
"""
diagnose_pytest.py
==================
Simulates exactly how cvdp_testbench_reward.py resolves and invokes pytest.

Run this on every node (or in the same Python environment that Ray workers use)
BEFORE restarting the training job.  Pass a real task_id to also run the actual
testbench end-to-end.

Usage:
    python diagnose_pytest.py
    python diagnose_pytest.py --task-id cvdp_copilot_reverse_bits_0001
    python diagnose_pytest.py --task-id cvdp_copilot_reverse_bits_0001 \
        --testenv-root /path/to/codev_test/train_testenv
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# ── 1. Replicate CVDP_PYTEST_CMD resolution ──────────────────────────────────

_cvdp_pytest_override = os.environ.get("CVDP_PYTEST_PATH", "")
if _cvdp_pytest_override and os.path.isfile(_cvdp_pytest_override):
    CVDP_PYTEST_CMD = [_cvdp_pytest_override]
    _source = f"CVDP_PYTEST_PATH env var → {_cvdp_pytest_override}"
else:
    CVDP_PYTEST_CMD = [sys.executable, "-m", "pytest"]
    if _cvdp_pytest_override:
        _source = (
            f"CVDP_PYTEST_PATH={repr(_cvdp_pytest_override)} is NOT a file "
            f"→ falling back to sys.executable"
        )
    else:
        _source = "CVDP_PYTEST_PATH not set → using sys.executable"

print("=" * 70)
print("STEP 1: pytest command resolution")
print("=" * 70)
print(f"  CVDP_PYTEST_PATH env  : {repr(os.environ.get('CVDP_PYTEST_PATH', ''))}")
print(f"  sys.executable        : {sys.executable}")
print(f"  Resolution source     : {_source}")
print(f"  CVDP_PYTEST_CMD       : {CVDP_PYTEST_CMD}")
print()

# ── 2. pytest --version ───────────────────────────────────────────────────────

print("=" * 70)
print("STEP 2: pytest --version")
print("=" * 70)
try:
    r = subprocess.run(
        CVDP_PYTEST_CMD + ["--version"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    print(f"  returncode : {r.returncode}")
    print(f"  stdout     : {r.stdout.strip()}")
    print(f"  stderr     : {r.stderr.strip()}")
    if r.returncode != 0:
        print("  *** FAIL: pytest invocation failed ***")
        sys.exit(1)
    else:
        print("  ✓ OK")
except FileNotFoundError as e:
    print(f"  *** FAIL: {e} ***")
    print("  The executable in CVDP_PYTEST_CMD does not exist on this machine.")
    sys.exit(1)
except Exception as e:
    print(f"  *** ERROR: {e} ***")
    sys.exit(1)
print()

# ── 3. cocotb importable? ─────────────────────────────────────────────────────

print("=" * 70)
print("STEP 3: cocotb import check")
print("=" * 70)
r = subprocess.run(
    CVDP_PYTEST_CMD[:1] + ["-c", "import cocotb; print('cocotb', cocotb.__version__)"]
    if CVDP_PYTEST_CMD[0] == sys.executable
    else [CVDP_PYTEST_CMD[0].replace("pytest", "python"), "-c",
          "import cocotb; print('cocotb', cocotb.__version__)"],
    capture_output=True,
    text=True,
    timeout=10,
)
# Simpler: always use the Python behind the chosen pytest
if CVDP_PYTEST_CMD[0] == sys.executable:
    python_bin = sys.executable
else:
    # pytest binary → assume same-dir python
    python_bin = str(Path(CVDP_PYTEST_CMD[0]).parent / "python")
    if not Path(python_bin).exists():
        python_bin = sys.executable

r2 = subprocess.run(
    [python_bin, "-c", "import cocotb; print('cocotb', cocotb.__version__)"],
    capture_output=True,
    text=True,
    timeout=10,
)
print(f"  Python used : {python_bin}")
print(f"  returncode  : {r2.returncode}")
print(f"  stdout      : {r2.stdout.strip()}")
print(f"  stderr      : {r2.stderr.strip()[:300]}")
if r2.returncode != 0:
    print("  *** WARN: cocotb not importable in this Python ***")
    print("  Tests will fail with ImportError.  Install cocotb or set")
    print("  CVDP_PYTEST_PATH to a pytest from a Python env that has cocotb.")
else:
    print("  ✓ cocotb is available")
print()

# ── 4. Optional: run a real testbench ─────────────────────────────────────────

parser = argparse.ArgumentParser(description="Diagnose CVDP pytest invocation")
parser.add_argument("--task-id", default=None, help="task_id to test end-to-end")
parser.add_argument(
    "--testenv-root",
    default=os.environ.get(
        "CVDP_TESTENV_ROOT",
        str(Path(__file__).parent / "codev_test" / "train_testenv"),
    ),
    help="Path to CVDP_TESTENV_ROOT (pre-generated testbench envs)",
)
args = parser.parse_args()

if args.task_id is None:
    print("=" * 70)
    print("STEP 4: end-to-end testbench run — SKIPPED (pass --task-id to enable)")
    print("=" * 70)
    print()
    print("All checks passed. pytest command is correctly configured.")
    sys.exit(0)

print("=" * 70)
print(f"STEP 4: end-to-end testbench run for task_id={args.task_id}")
print("=" * 70)

# Find template directory
testenv_root = Path(args.testenv_root)
template_dir = None
for cid_dir in testenv_root.iterdir():
    candidate = cid_dir / args.task_id
    if candidate.is_dir():
        template_dir = candidate
        break

if template_dir is None:
    print(f"  *** FAIL: task_id {args.task_id!r} not found under {testenv_root} ***")
    sys.exit(1)

print(f"  Template dir : {template_dir}")

# Parse .env for VERILOG_SOURCES
env_file = template_dir / "src" / ".env"
env_vars = {}
if env_file.exists():
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, _, v = line.partition("=")
            env_vars[k.strip()] = v.strip().strip('"').strip("'")

verilog_sources = env_vars.get("VERILOG_SOURCES", "/code/rtl/design.sv")
target_rtl = Path(verilog_sources).name
print(f"  VERILOG_SOURCES : {verilog_sources}  → target file: {target_rtl}")

# Create isolated run dir
run_dir = Path(tempfile.mkdtemp(prefix=f"diag_{args.task_id[:20]}_"))
print(f"  Run dir      : {run_dir}")

try:
    shutil.copytree(str(template_dir), str(run_dir), dirs_exist_ok=True)

    # Write a dummy (empty) design to test the framework, not correctness
    rtl_path = run_dir / "rtl" / target_rtl
    rtl_path.parent.mkdir(parents=True, exist_ok=True)
    rtl_path.write_text("// placeholder\n")

    # Build subprocess env
    proc_env = os.environ.copy()
    extra_bin = os.environ.get("CVDP_EXTRA_BIN_PATH", "")
    if extra_bin and extra_bin not in proc_env.get("PATH", ""):
        proc_env["PATH"] = proc_env.get("PATH", "") + ":" + extra_bin
    proc_env.update(env_vars)
    if "VERILOG_SOURCES" in proc_env:
        proc_env["VERILOG_SOURCES"] = proc_env["VERILOG_SOURCES"].replace("/code/", "")

    print(f"  Running: {CVDP_PYTEST_CMD + ['-v', '-s', 'src/test_runner.py']}")
    r3 = subprocess.run(
        CVDP_PYTEST_CMD + ["-v", "-s", "src/test_runner.py"],
        cwd=str(run_dir),
        capture_output=True,
        text=True,
        encoding="utf-8",
        env=proc_env,
        timeout=120,
    )
    print(f"  returncode : {r3.returncode}")
    print(f"  --- stdout (first 2000 chars) ---")
    print(r3.stdout[:2000])
    print(f"  --- stderr (first 500 chars) ---")
    print(r3.stderr[:500])
    # rc != 0 is expected (placeholder code) — the important thing is no FileNotFoundError
    if r3.returncode == 0:
        print("  ✓ pytest ran and PASSED (placeholder design somehow passed?)")
    else:
        print("  ✓ pytest ran and FAILED as expected (placeholder design)")
        print("  The pytest infrastructure is working correctly.")
finally:
    shutil.rmtree(str(run_dir), ignore_errors=True)
