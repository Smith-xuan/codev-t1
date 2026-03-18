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

def runner(DATA_WIDTH: int = 16, LEARNING_RATE: int = 1):
    # Simulation parameters
    parameter = {
        "DATA_WIDTH": DATA_WIDTH,
        "LEARNING_RATE": LEARNING_RATE
    }

    # Debug information
    print(f"[DEBUG] Running simulation with DATA_WIDTH={DATA_WIDTH}")
    print(f"[DEBUG] Running simulation with LEARNING_RATE={LEARNING_RATE}")
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

# Generate minimum, default, and random sizes
random_data_width    = [2] + [16] + [random.randint(8, 32) for _ in range(2)]
random_learning_rate = [0, 1, 2]

# Parametrize test for different random data sizes
@pytest.mark.parametrize("DATA_WIDTH", random_data_width)
@pytest.mark.parametrize("LEARNING_RATE", random_learning_rate)
@pytest.mark.parametrize("test", range(5))
def test_data(DATA_WIDTH, LEARNING_RATE, test):
    # Run the simulation with specified parameters
    runner(DATA_WIDTH=DATA_WIDTH, LEARNING_RATE=LEARNING_RATE)