import cocotb
import os
import pytest
import random
from cocotb_tools.runner import get_runner

# Environment configuration
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

def runner(STARVATION_THRESHOLD: int = 8):
    # Simulation parameters
    parameter = {
        "STARVATION_THRESHOLD": STARVATION_THRESHOLD
    }

    # Debug information
    print(f"[DEBUG] Running simulation with STARVATION_THRESHOLD={STARVATION_THRESHOLD}")
    print(f"[DEBUG] Parameters: {parameter}")

    # Configure and run the simulation
    sim_runner = get_runner(sim)
    sim_runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameter,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log"
    )

    # Run the test
    sim_runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)

# Generate random values for testing
random_starvation_threshold = [5] + [random.randint(5, 20) for _ in range(10)]

# Parametrize test for different random data sizes
@pytest.mark.parametrize("STARVATION_THRESHOLD", random_starvation_threshold)
def test_data(STARVATION_THRESHOLD):
    # Run the simulation with specified parameters
    runner(STARVATION_THRESHOLD=STARVATION_THRESHOLD)