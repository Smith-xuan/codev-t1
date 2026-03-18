
import os
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = os.getenv("WAVE")

def test_runner(DEBUG_MODE: int=0, WIDTH: int =4):
    parameter = {"DEBUG_MODE":DEBUG_MODE, "WIDTH":WIDTH}
    
    # Debug information
    print(f"[DEBUG] Running simulation with DEBUG_MODE={DEBUG_MODE}, WIDTH={WIDTH}")
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
        timescale=("1ns", "1ns"),
        log_file="build.log")

    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)   

# Parametrize test for different DEBUG_MODE 
@pytest.mark.parametrize("DEBUG_MODE", [0,1])
@pytest.mark.parametrize("WIDTH", [4,5])

def test_gray_to_binary(DEBUG_MODE, WIDTH):
    # Run the simulation with specified parameters
    test_runner(DEBUG_MODE=DEBUG_MODE, WIDTH=WIDTH)
