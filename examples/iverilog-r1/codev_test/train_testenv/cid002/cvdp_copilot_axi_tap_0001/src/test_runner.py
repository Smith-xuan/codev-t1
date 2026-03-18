import os
from cocotb_tools.runner import get_runner
import pytest
import random

verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def runner(ADDR_WIDTH: int=0 ,DATA_WIDTH: int=0):
    parameter = {"ADDR_WIDTH":ADDR_WIDTH,"DATA_WIDTH":DATA_WIDTH}
    # Debug information
    print(f"[DEBUG] Parameters: {parameter}")
    
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameter,
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log")
        
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)
@pytest.mark.parametrize("ADDR_WIDTH", [32])
@pytest.mark.parametrize("DATA_WIDTH", [random.randint(8, 64),random.randint(8, 32)])
# random test
@pytest.mark.parametrize("test", range(10))
def test_pipeline_mac(ADDR_WIDTH, DATA_WIDTH, test):
    runner(ADDR_WIDTH=ADDR_WIDTH, DATA_WIDTH=DATA_WIDTH)