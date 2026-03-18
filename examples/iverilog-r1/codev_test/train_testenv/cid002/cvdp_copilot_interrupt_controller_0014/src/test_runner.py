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

def runner(NUM_INTERRUPTS: int = 8):
    # Simulation parameters
    parameter = {
        "NUM_INTERRUPTS": NUM_INTERRUPTS
    }

    # Debug information
    print(f"[DEBUG] Running simulation with NUM_INTERRUPTS={NUM_INTERRUPTS}")
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
random_num_irq = [1,8] + [random.randint(1, 10) for _ in range(5)]

# Parametrize test for different random data sizes
@pytest.mark.parametrize("NUM_INTERRUPTS", random_num_irq)
def test_data(NUM_INTERRUPTS):
    # Run the simulation with specified parameters
    runner(NUM_INTERRUPTS=NUM_INTERRUPTS)