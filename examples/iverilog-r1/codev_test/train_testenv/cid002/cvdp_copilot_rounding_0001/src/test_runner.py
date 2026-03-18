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
width_values = [8, 16, 24, 32]  # Test different WIDTH parameters

@pytest.mark.parametrize("WIDTH", width_values)
def test_rounding(WIDTH):
    """
    Parameterized test_runner to verify the rounding module for multiple WIDTH values.
    """
    print(f"Running simulation with WIDTH = {WIDTH}")
    runner = get_runner(sim)
    
    # Build and simulate with parameters
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters={
            'WIDTH': WIDTH
        },
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ps"),
        log_file=f"sim_WIDTH_{WIDTH}.log"
    )

    runner.test(
        hdl_toplevel=toplevel,
        test_module=module,
        waves=True
    )
