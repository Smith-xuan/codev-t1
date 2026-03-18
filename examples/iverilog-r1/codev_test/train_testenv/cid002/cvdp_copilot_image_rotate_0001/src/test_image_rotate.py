import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import harness_library as hrs_lb
import math

# ----------------------------------------
# - Image Rotate Test
# ----------------------------------------
@cocotb.test()
async def verify_image_rotate(dut):
  """
  Verify the DUT's image rotate functionality.

  This test performs the following steps:
  1. Initializes the DUT
  2. Dynamically generates random input images and applies them to the DUT.
  3. Compares the DUT output with the expected rotated image result.

  """
  # Initialize DUT inputs
  await hrs_lb.dut_init(dut)

  await Timer(10, units="ns")

  # Retrieve DUT configuration parameters
  rows_in = int(dut.IN_ROW.value)
  cols_in = int(dut.IN_COL.value)
  rows_out = max(rows_in,cols_in)
  cols_out = max(rows_in,cols_in)
  data_width = int(dut.DATA_WIDTH.value)
  num_inputs = 10 # Multiple input sets generated dynamically

  # Print Input Image dimensions for debugging
  print(f"IN_ROW: {rows_in}, IN_COL: {cols_in}")
  print(f"DATA_WIDTH: {data_width}")

  for i in range(num_inputs):
    rotation_angle = random.randint(0, 3) # Random Rotation angle (0-3)

    # Generate a random input image
    image_in = hrs_lb.populate_image(rows_in, cols_in, data_width)
    
    # Flatten the 2D input image to a 1D representation for DUT compatibility
    image_in_flat = hrs_lb.convert_2d_to_flat(image_in, data_width)

    # Apply inputs to DUT
    dut.image_in.value = image_in_flat
    dut.rotation_angle.value = rotation_angle

    await Timer(1, units="ns")  # Allow DUT to process inputs

    # Calculate expected output
    expected_image_out = hrs_lb.calculate_rotated_image(image_in, rotation_angle, rows_out)

    # Read the DUT output image in flattened form
    image_out_flat = int(dut.image_out.value)

    # Convert the flattened output back to a 2D image for verification
    image_out = hrs_lb.convert_flat_to_2d(image_out_flat, cols_out, rows_out, data_width)

    # Verify that the DUT output matches the expected rotated image result
    assert image_out == expected_image_out, f"Test {i+1}: Image Out does not match the expected result: {image_out} != {expected_image_out}"

    print(f"Test {i+1} passed")

    await Timer(10, units="ns")


