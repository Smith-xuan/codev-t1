# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# test_runner.py

import os
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")

# Define parameter sets for MaxRatio_g and Latency_g
max_ratio_values = [5, 10, 20]
latency_values = [0, 1]

@pytest.mark.parametrize("MaxRatio_g", max_ratio_values)
@pytest.mark.parametrize("Latency_g", latency_values)
def test_pytest(MaxRatio_g, Latency_g):
    """
    Parameterized test_runner that tests all combinations of MaxRatio_g and Latency_g.
    """
    print(f"Running with: MaxRatio_g = {MaxRatio_g}, Latency_g = {Latency_g}")
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters={
            'MaxRatio_g': MaxRatio_g,
            'Latency_g': Latency_g
        },
        # Arguments
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ps"),
        log_file="sim.log"
    )
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)
