import os
from pathlib import Path
from cocotb_tools.runner import get_runner
import pytest
import re
import logging

# List from Files
verilog_sources = os.getenv("VERILOG_SOURCES").split()
    
# Language of Top Level File
toplevel_lang = os.getenv("TOPLEVEL_LANG")
sim = os.getenv("SIM", "icarus")
toplevel = os.getenv("TOPLEVEL")
module = os.getenv("MODULE")

def test_runner(IMG_WIDTH_IN=10, IMG_HEIGHT_IN=10, IMG_WIDTH_OUT=5, IMG_HEIGHT_OUT=5, BORDER_COLOR=0xFFFF):
    """
    Test Runner for AXIS Image Border Generator
    """

    # Parameterize the test
    parameter_defines = {
        "IMG_WIDTH_IN": IMG_WIDTH_IN,
        "IMG_HEIGHT_IN": IMG_HEIGHT_IN,
        "IMG_WIDTH_OUT": IMG_WIDTH_OUT,
        "IMG_HEIGHT_OUT": IMG_HEIGHT_OUT,
        "BORDER_COLOR": BORDER_COLOR,
    }
    print(f"Running simulation with parameters: {parameter_defines}")
    
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameter_defines,
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ps"),
        log_file="sim.log",
        defines={"SIMULATION": None}
    )

    plusargs = [
        f"+IMG_WIDTH_IN={IMG_WIDTH_IN}",
        f"+IMG_HEIGHT_IN={IMG_HEIGHT_IN}",
        f"+IMG_WIDTH_OUT={IMG_WIDTH_OUT}",
        f"+IMG_HEIGHT_OUT={IMG_HEIGHT_OUT}",
        f"+BORDER_COLOR={BORDER_COLOR}"
    ]
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True, plusargs=plusargs)

@pytest.mark.parametrize("IMG_WIDTH_IN,IMG_HEIGHT_IN,IMG_WIDTH_OUT,IMG_HEIGHT_OUT",[(10, 10, 5, 5), (12, 12, 4, 4), (16, 16, 9, 5)])

def test_axis_border_gen_with_resize(IMG_WIDTH_IN, IMG_HEIGHT_IN, IMG_WIDTH_OUT, IMG_HEIGHT_OUT):
    """Parameterized Test for AXIS Border Generator with Resizer"""

    BORDER_COLOR = 0xFFFF  # Default border color
    print(f"Test Runner: IMG_WIDTH_IN={IMG_WIDTH_IN}, IMG_HEIGHT_IN={IMG_HEIGHT_IN}, IMG_WIDTH_OUT={IMG_WIDTH_OUT}, IMG_HEIGHT_OUT={IMG_HEIGHT_OUT}")
    test_runner(
        IMG_WIDTH_IN=IMG_WIDTH_IN,
        IMG_HEIGHT_IN=IMG_HEIGHT_IN,
        IMG_WIDTH_OUT=IMG_WIDTH_OUT,
        IMG_HEIGHT_OUT=IMG_HEIGHT_OUT,
        BORDER_COLOR=BORDER_COLOR
    )