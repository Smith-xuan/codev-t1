import os
from cocotb_tools.runner import get_runner
import pytest
import random

# Verilog sources and test settings
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang = os.getenv("TOPLEVEL_LANG")
sim = os.getenv("SIM", "icarus")
toplevel = os.getenv("TOPLEVEL")
module = os.getenv("MODULE")
wave = bool(os.getenv("WAVE"))

def runner(JITTER_THRESHOLD: int=5, system_clk : int=0):
    # Define plusargs and parameters to pass into the simulator
    plusargs = [f'+system_clk={system_clk}']
    parameter = {"JITTER_THRESHOLD": JITTER_THRESHOLD}
    
    # Debug information
    print(f"[DEBUG] Running simulation with JITTER_THRESHOLD={JITTER_THRESHOLD}")
    print(f"[DEBUG] Parameters: {parameter}")
    
    # Create a simulator runner instance
    runner = get_runner(sim)
    
    # Build the simulation
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameter,
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log"
    )
    
    # Run the tests
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)

# Randomized test with parameterization
@pytest.mark.parametrize("JITTER_THRESHOLD", [5,7,10])  # Different threshold values to test
@pytest.mark.parametrize("test", range(2))
def test_clock_jitter_detection(JITTER_THRESHOLD, test):
    """Test clock jitter detection with different JITTER_THRESHOLD values."""
    runner(JITTER_THRESHOLD=JITTER_THRESHOLD)
