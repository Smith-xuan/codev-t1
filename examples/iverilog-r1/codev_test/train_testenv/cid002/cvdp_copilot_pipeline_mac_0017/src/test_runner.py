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

def runner(DWIDTH: int=0 , N: int=0 , multiplicand : int=0, multiplier : int=0, valid_i : int=0):
    plusargs=[f'+multiplicand={multiplicand}', f'+multiplier={multiplier}', f'+valid_i={valid_i}']
    parameter = {"DWIDTH":DWIDTH, "N":N}
    # Debug information
    print(f"[DEBUG] Running simulation with DWIDTH={DWIDTH}, N={N}")
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
@pytest.mark.parametrize("DWIDTH", [ random.randint(1, 64)])
@pytest.mark.parametrize("N", [random.randint(5, 32), random.randint(5, 32), random.randint(5, 24)] )
# @pytest.mark.parametrize("N", [5] )
# random test
@pytest.mark.parametrize("test", range(3))
def test_pipeline_mac(DWIDTH, N, test):
    runner(DWIDTH=DWIDTH, N=N)
