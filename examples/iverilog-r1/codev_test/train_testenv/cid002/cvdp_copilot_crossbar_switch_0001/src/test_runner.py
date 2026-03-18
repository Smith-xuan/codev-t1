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

def runner(DATA_WIDTH: int=0, in0 : int=0,in1 : int=0,in2 : int=0,in3 : int=0,valid_in0 : int=0,valid_in1 : int=0,valid_in2 : int=0,valid_in3 : int=0,):
    plusargs=[f'+in0={in0}',f'+in1={in1}',f'+in2={in2}',f'+in3={in3}', f'+valid_in0={valid_in0}', f'+valid_in1={valid_in1}', f'+valid_in2={valid_in2}', f'+valid_in3={valid_in3}']
    parameter = {"DATA_WIDTH":DATA_WIDTH}
    # Debug information
    print(f"[DEBUG] Running simulation with DATA_WIDTH={DATA_WIDTH}")
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
@pytest.mark.parametrize("DATA_WIDTH", [ random.randint(4, 64), random.randint(4, 64), random.randint(4, 64)])
# random test
@pytest.mark.parametrize("test", range(1))
def test_crossbar_switch(DATA_WIDTH, test):
    runner(DATA_WIDTH=DATA_WIDTH)
