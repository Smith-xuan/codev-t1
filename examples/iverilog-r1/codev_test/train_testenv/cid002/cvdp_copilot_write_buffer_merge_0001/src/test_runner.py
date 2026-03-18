import os
from cocotb_tools.runner import get_runner
import random
import pytest
from datetime import datetime  # Import datetime for timestamp
import harness_library as hrs_lb
import math

# Fetch environment variables
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

# This function prepares and triggers the simulation.
# It sets up the simulation environment, defines parameters, and runs the specified testbench.
def runner(INPUT_DATA_WIDTH: int=32, INPUT_ADDR_WIDTH: int=16, BUFFER_DEPTH: int=8):
  # Define simulation parameters
  parameter = {
    "INPUT_DATA_WIDTH": INPUT_DATA_WIDTH,
    "INPUT_ADDR_WIDTH": INPUT_ADDR_WIDTH,
    "BUFFER_DEPTH": BUFFER_DEPTH,
  }

  # # Prepare plusargs, which are passed to the DUT
  # plusargs = [
  # ]

  # Set up the runner for the simulator
  runner = get_runner(sim)
  runner.build(
    sources=verilog_sources,
    hdl_toplevel=toplevel,
    # Arguments
    parameters=parameter,
    always=True,
    clean=True,
    waves=wave,
    verbose=True,
    timescale=("1ns", "1ns"),
    log_file="sim.log")
  runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave)

  # Save the VCD (waveform) after running the test with a unique timestamp
  timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")  # Unique timestamp
  test_name = f"{toplevel}_INPUT_DATA_WIDTH_{INPUT_DATA_WIDTH}_INPUT_ADDR_WIDTH_{INPUT_ADDR_WIDTH}_BUFFER_DEPTH_{BUFFER_DEPTH}_{timestamp}"
  # hrs_lb.save_vcd(wave, toplevel, test_name)

# ---------------------------------------------------------------------------
# Random Parameterized Write Buffer Merge Tests
# ---------------------------------------------------------------------------
# Generate random parameters for the write_buffer_merge testbench and run the test multiple times.
@pytest.mark.parametrize("random_test", range(10))
def test_random_write_buffer_merge(random_test):
  # Generate random parameters
  INPUT_DATA_WIDTH = random.randint(1, 32)  # Random input data width (1 to 32 bits)
  INPUT_ADDR_WIDTH = random.randint(1, 32)  # Random input address width (1 to 32 bits)
  # Calculate BUFFER_DEPTH as a power of 2 based on a random value between 1 and INPUT_ADDR_WIDTH
  # Ensures that BUFFER_DEPTH is always a power of 2 and <= 2^INPUT_ADDR_WIDTH
  BUFFER_DEPTH = 2**(math.ceil(math.log2(random.randint(1, INPUT_ADDR_WIDTH))))

  # Run the test with the generated parameters
  runner(INPUT_DATA_WIDTH=INPUT_DATA_WIDTH, INPUT_ADDR_WIDTH=INPUT_ADDR_WIDTH, BUFFER_DEPTH=BUFFER_DEPTH)

# ---------------------------------------------------------------------------
# Random Parameterized Write Buffer Merge Tests with BUFFER_DEPTH = 1
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("random_test", range(5))
def test_random_passthrough_write_buffer_merge(random_test):
  # Generate random parameters
  INPUT_DATA_WIDTH = random.randint(1, 32)  # Random input data width (1 to 32 bits)
  INPUT_ADDR_WIDTH = random.randint(1, 32)  # Random input address width (1 to 32 bits)
  # Test Passthrough Case when BUFFER_DEPTH = 1
  BUFFER_DEPTH = 1

  # Run the test with the generated parameters
  runner(INPUT_DATA_WIDTH=INPUT_DATA_WIDTH, INPUT_ADDR_WIDTH=INPUT_ADDR_WIDTH, BUFFER_DEPTH=BUFFER_DEPTH)
