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

def runner(DATA_WIDTH: int = 32, ADDR_WIDTH: int = 4):
    # Simulation parameters
    parameter = {
        "DATA_WIDTH": DATA_WIDTH,
        "ADDR_WIDTH": ADDR_WIDTH,
    }

    # Debug information
    print(f"[DEBUG] Running simulation with DATA_WIDTH={DATA_WIDTH}, ADDR_WIDTH={ADDR_WIDTH}")
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

# Generate random values for DATA_WIDTH and ADDR_WIDTH
random_data_widths = [8, 32, 64, random.choice([16, 128]) if random.choice([16, 128]) % 2 == 0 else random.choice([16, 128]) + 1]
random_addr_widths = [4, 8, random.choice([2, 8]) if random.choice([2, 8]) % 2 == 0 else random.choice([2, 8]) + 1]

# Parametrize test for different combinations of DATA_WIDTH and ADDR_WIDTH
@pytest.mark.parametrize("DATA_WIDTH", random_data_widths)
@pytest.mark.parametrize("ADDR_WIDTH", random_addr_widths)
@pytest.mark.parametrize("test", range(1))
def test_data(DATA_WIDTH, ADDR_WIDTH, test):
    # Run the simulation with specified parameters
    runner(DATA_WIDTH=DATA_WIDTH, ADDR_WIDTH=ADDR_WIDTH)