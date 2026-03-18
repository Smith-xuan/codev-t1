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

def runner(
    MEM_ADDR_WIDTH: int,
    SPRITE_WIDTH: int,
    SPRITE_HEIGHT: int,
    WAIT_WIDTH: int,
    N_ROM: int,
):
    # Simulation parameters
    parameter = {
        "MEM_ADDR_WIDTH": MEM_ADDR_WIDTH,
        "SPRITE_WIDTH": SPRITE_WIDTH,
        "SPRITE_HEIGHT": SPRITE_HEIGHT,
        "WAIT_WIDTH": WAIT_WIDTH,
        "N_ROM": N_ROM,
    }

    # Debug information
    print(f"[DEBUG] Running simulation with parameters: {parameter}")

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
        log_file="sim.log",
    )

    # Run the test
    sim_runner.test(hdl_toplevel=toplevel, test_module=module, waves=True)


# Generate dependent random values for testing
def generate_parameters():
    # Define maximum N_ROM
    n_rom = random.choice([256, 512])

    # Calculate MEM_ADDR_WIDTH based on N_ROM
    mem_addr_width = n_rom.bit_length() - 1

    # Generate SPRITE_WIDTH and SPRITE_HEIGHT based on N_ROM
    max_dimension = int(n_rom ** 0.5)
    sprite_width = random.choice([d for d in [4, 8, 16] if d <= max_dimension])
    sprite_height = n_rom // sprite_width

    # WAIT_WIDTH between 2 and 6
    wait_width = random.randint(2, 6)

    return {
        "MEM_ADDR_WIDTH": mem_addr_width,
        "SPRITE_WIDTH": sprite_width,
        "SPRITE_HEIGHT": sprite_height,
        "WAIT_WIDTH": wait_width,
        "N_ROM": n_rom,
    }

# Generate a single test parameter set
random_parameters = [generate_parameters() for _ in range(5)]

# Parametrize test for different random data sizes
@pytest.mark.parametrize("param_set", random_parameters)
@pytest.mark.parametrize("test", range(10))
def test_data(param_set, test):
    # Extract parameters from the set
    runner(
        MEM_ADDR_WIDTH=param_set["MEM_ADDR_WIDTH"],
        SPRITE_WIDTH=param_set["SPRITE_WIDTH"],
        SPRITE_HEIGHT=param_set["SPRITE_HEIGHT"],
        WAIT_WIDTH=param_set["WAIT_WIDTH"],
        N_ROM=param_set["N_ROM"],
    )