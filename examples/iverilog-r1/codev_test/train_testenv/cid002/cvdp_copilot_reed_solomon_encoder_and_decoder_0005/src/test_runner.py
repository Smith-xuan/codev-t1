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

def runner(N: int=255, K : int=253):
    # Define plusargs and parameters to pass into the simulator
    parameter = {"N": N, "K" : K}
    
    # Debug information
    print(f"[DEBUG] Running simulation with N={N} and K={K}")
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
@pytest.mark.parametrize("test", range(10))

def test_reed_solomon_encoder(test):
    # Randomize K within a valid range
    K = random.randint(16, 253)  # Assuming 253 is the maximum valid value for K
    N = K + 2  # Calculate N based on K
    print(f"[DEBUG] Test {test + 1}: Randomized K={K}, Calculated N={N}")
    # Pass the randomized values to the runner
    runner(N=N, K=K)