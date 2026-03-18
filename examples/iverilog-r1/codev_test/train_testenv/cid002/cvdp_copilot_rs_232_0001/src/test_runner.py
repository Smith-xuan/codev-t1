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

def runner(CLOCK_FREQ: int=0 ,BAUD_RATE: int=0):
    # plusargs= [f'+tx_datain_ready={tx_datain_ready}', f'+Present_Processing_Completed={Present_Processing_Completed}', f'+tx_datain={tx_datain}', f'+tx_transmitter={tx_transmitter}', f'+tx_transmitter_valid={tx_transmitter_valid}']
    parameter = {"CLOCK_FREQ":CLOCK_FREQ,"BAUD_RATE":BAUD_RATE}
    # Debug information
    print(f"[DEBUG] Running simulation with CLOCK_FREQ={CLOCK_FREQ},CLOCK_FREQ={CLOCK_FREQ}")
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
@pytest.mark.parametrize("CLOCK_FREQ", [100000000,200000000,250000000])
@pytest.mark.parametrize("BAUD_RATE", [19200,115200])
# random test
@pytest.mark.parametrize("test", range(1))
def test_copilot_rs_232(CLOCK_FREQ, BAUD_RATE, test):
    runner(CLOCK_FREQ=CLOCK_FREQ, BAUD_RATE=BAUD_RATE)