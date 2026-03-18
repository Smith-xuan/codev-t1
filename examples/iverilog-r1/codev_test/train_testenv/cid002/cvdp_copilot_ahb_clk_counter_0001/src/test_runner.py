import os
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))


def call_runner(data_width: int = 32, addr_width: int = 32):
    parameters = {
        "ADDR_WIDTH": addr_width,
        "DATA_WIDTH": data_width
    }
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log")
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave)


# random test
@pytest.mark.parametrize("test", range(1))
def test_run(test):
    call_runner()

    # Test with different parameter values
    call_runner(8, 8)
    call_runner(8, 16)
    call_runner(8, 32)
    call_runner(16, 32)
