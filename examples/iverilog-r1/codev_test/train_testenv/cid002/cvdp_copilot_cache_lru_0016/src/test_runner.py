import cocotb
import os
import pytest
from cocotb_tools.runner import get_runner
import math

# Environment configuration
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def call_runner(NWAYS: int = 4, NINDEXES: int = 32, COUNTERW: int = 2):
    parameters = {
        "NWAYS": NWAYS,
        "NINDEXES": NINDEXES,
        "COUNTERW": COUNTERW
    }
    # Configure and run the simulation
    sim_runner = get_runner(sim)
    sim_runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log"
    )

    # Run the test
    sim_runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)

@pytest.mark.parametrize("test", range(1))
def test_data(test):
    # Run the simulation
    call_runner()

    # Run the simulation with different parameters
    call_runner(8, 16, math.ceil(math.log2(8)))
    call_runner(8, 16, math.ceil(math.log2(8))+1)
    call_runner(8, 16, math.ceil(math.log2(8))-1)
    call_runner(16, 64)
    call_runner(16, 64, math.ceil(math.log2(16)))
