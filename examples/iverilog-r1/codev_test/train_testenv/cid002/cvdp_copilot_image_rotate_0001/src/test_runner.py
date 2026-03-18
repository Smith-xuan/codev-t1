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

# The main runner function to trigger image rotate tests
# This function prepares the simulation environment, sets parameters, and runs the test
def runner(IN_ROW: int=4, IN_COL: int=4, DATA_WIDTH: int=8):
  # Define simulation parameters
  parameter = {
    "IN_ROW": IN_ROW,
    "IN_COL": IN_COL,
    "DATA_WIDTH": DATA_WIDTH,
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
  test_name = f"{toplevel}_IN_ROW_{IN_ROW}_IN_COL_{IN_COL}_WIDTH_{DATA_WIDTH}_{timestamp}"
  # hrs_lb.save_vcd(wave, toplevel, test_name)


# Random Image Rotate Tests
# Generate random parameters for the image rotate testbench and run the test multiple times
@pytest.mark.parametrize("random_test", range(10))
def test_random_image_rotate(random_test):
  # Generate random dimensions for the matrices
  IN_ROW = random.randint(1, 8)
  IN_COL = random.randint(1, 8)
  DATA_WIDTH = random.randint(1, 16)

  # Run the test with the generated parameters
  runner(IN_ROW=IN_ROW, IN_COL=IN_COL, DATA_WIDTH=DATA_WIDTH)
