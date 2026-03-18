import os
from cocotb_tools.runner import get_runner
import random
import pytest
from datetime import datetime  # Import datetime for timestamp
import harness_library as hrs_lb

# Fetch environment variables
verilog_sources = os.getenv("VERILOG_SOURCES").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

# The main runner function to trigger Synchronous Muller C Element tests
# This function prepares the simulation environment, sets parameters, and runs the test
def runner(NUM_INPUT: int=2, PIPE_DEPTH: int=1):
  # Define simulation parameters
  parameter = {
    "NUM_INPUT": NUM_INPUT,
    "PIPE_DEPTH": PIPE_DEPTH,
  }

  # Prepare plusargs, which are passed to the DUT
  plusargs = []

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
  runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave, plusargs=plusargs)

  # Save the VCD (waveform) after running the test with a unique timestamp
  timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")  # Unique timestamp
  test_name = f"{toplevel}_NUM_INPUT_{NUM_INPUT}_PIPE_DEPTH_{PIPE_DEPTH}_{timestamp}"
  # hrs_lb.save_vcd(wave, toplevel, test_name)


# Random Synchronous Muller C Element Tests
# Generate random parameters for the Synchronous Muller C Element testbench and run the test multiple times
@pytest.mark.parametrize("random_test", range(10))
def test_random_sync_muller_c_element(random_test):
  # Generate random dimensions for the matrices
  NUM_INPUT = random.randint(1, 8)
  PIPE_DEPTH = random.randint(1, 8)

  # Run the test with the generated parameters
  runner(NUM_INPUT=NUM_INPUT, PIPE_DEPTH=PIPE_DEPTH)
