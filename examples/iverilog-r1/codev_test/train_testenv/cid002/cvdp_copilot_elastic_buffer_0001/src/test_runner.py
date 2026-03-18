# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# test_runner.py

import os
from pathlib import Path
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = os.getenv("WAVE")

def test_runner(WIDTH: int=16, ERR_TOLERANCE: int=4):
    
    parameter = {"WIDTH":WIDTH, "ERR_TOLERANCE":ERR_TOLERANCE,}
    # Debug information
    print(f"[DEBUG] Running simulation with WIDTH={WIDTH}, ERR_TOLERANCE={ERR_TOLERANCE}")
    print(f"[DEBUG] Parameters: {parameter}")

    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,

        # Arguments
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        parameters=parameter,
        timescale=("1ns", "1ps"),
        log_file="sim.log")

    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)

# Parametrize test for different WIDTH and ERR_TOLERANCE
@pytest.mark.parametrize("WIDTH", [4, 16, 32, 64])
@pytest.mark.parametrize("ERR_TOLERANCE", [1, 4, 6])

def test_elastic_buffer_pattern_matcher(WIDTH, ERR_TOLERANCE):
    # Run the simulation with specified parameters
    test_runner(WIDTH=WIDTH, ERR_TOLERANCE=ERR_TOLERANCE)