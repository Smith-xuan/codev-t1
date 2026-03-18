import os
from pathlib import Path
from cocotb_tools.runner import get_runner
import re
import logging

# Collect environment variables
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang = os.getenv("TOPLEVEL_LANG")
sim = os.getenv("SIM", "icarus")
toplevel = os.getenv("TOPLEVEL")
module = os.getenv("MODULE")
wave = os.getenv("WAVE")

# Add test cases for multiple DATA_WIDTH values
test_cases = [8, 16, 32, 64]  # Define test cases for DATA_WIDTH
DATA_WIDTH = int(os.getenv("DATA_WIDTH", 64))  # Default DATA_WIDTH is 64

def test_runner():
    for width in test_cases:
        os.environ["DATA_WIDTH"] = str(width)  # Override DATA_WIDTH in environment variables
        runner = get_runner(sim)

        # Build step
        runner.build(
            sources=verilog_sources,
            hdl_toplevel=toplevel,
            parameters={"DATA_WIDTH": width},  # Pass DATA_WIDTH parameter
            always=True,
            clean=True,
            waves=wave,
            verbose=True,
            timescale=("1ns", "1ns"),
            log_file=f"build_{width}.log"
        )

        # Test step
        runner.test(
            hdl_toplevel=toplevel,
            test_module=module,
            waves=wave
        )
        print(f"Completed test for DATA_WIDTH = {width}")

if __name__ == "__main__":
    test_runner()
