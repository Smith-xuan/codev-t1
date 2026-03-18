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

def test_runner(IMG_WIDTH=3, IMG_HEIGHT=2):
    """
    Test Runner for AXIS Image Border Generator
    """

    # Parameterize the test
    parameter_defines = {
        "IMG_WIDTH": IMG_WIDTH,
        "IMG_HEIGHT": IMG_HEIGHT,
    }
    print(f"Running simulation with IMG_WIDTH={IMG_WIDTH}, IMG_HEIGHT={IMG_HEIGHT}")
    
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

    plusargs = [f"+IMG_WIDTH={IMG_WIDTH}", f"+IMG_HEIGHT={IMG_HEIGHT}"]
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True, plusargs=plusargs)

@pytest.mark.parametrize("IMG_WIDTH,IMG_HEIGHT", [(4, 4), (5, 2)])
def test_axis_image_border_gen(IMG_WIDTH, IMG_HEIGHT):
    """Parameterized test for AXIS Image Border Generator"""

    print(f"Test Runner: IMG_WIDTH={IMG_WIDTH}, IMG_HEIGHT={IMG_HEIGHT}")
    test_runner(IMG_WIDTH=IMG_WIDTH, IMG_HEIGHT=IMG_HEIGHT)