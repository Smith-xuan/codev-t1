# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# test_runner.py

import os
from cocotb_tools.runner import get_runner
import pytest

# Environment Variables
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG", "verilog")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL", "rounding")
module          = os.getenv("MODULE", "rounding_test")

# Parameter Values
width_values = [8, 16, 24, 32]  # Test different PKT_CNT_WIDTH parameters

@pytest.mark.parametrize("PKT_CNT_WIDTH", width_values)
def test_rounding(PKT_CNT_WIDTH):
    """
    Parameterized test_runner to verify the rounding module for multiple PKT_CNT_WIDTH values.
    """
    print(f"Running simulation with PKT_CNT_WIDTH = {PKT_CNT_WIDTH}")
    runner = get_runner(sim)
    
    # Build and simulate with parameters
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters={
            'PKT_CNT_WIDTH': PKT_CNT_WIDTH
        },
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ps"),
        log_file=f"sim_PKT_CNT_WIDTH_{PKT_CNT_WIDTH}.log"
    )

    runner.test(
        hdl_toplevel=toplevel,
        test_module=module,
        waves=True
    )
