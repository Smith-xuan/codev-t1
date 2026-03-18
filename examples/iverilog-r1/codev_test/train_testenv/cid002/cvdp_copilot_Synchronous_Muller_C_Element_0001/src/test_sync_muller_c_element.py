import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import harness_library as hrs_lb
import math

# ----------------------------------------
# - Synchornous Muller C Element Test
# ----------------------------------------

async def reset_dut(dut, duration_ns=10):
    """
    Perform a synchronous reset on the Design Under Test (DUT).

    - Sets the reset signal high for the specified duration.
    - Ensures all output signals are zero during the reset.
    - Deactivates the reset signal and stabilizes the DUT.

    Args:
        dut: The Design Under Test (DUT).
        duration_ns: The time duration in nanoseconds for which the reset signal will be held high.
    """
    dut.srst.value = 1  # Activate reset (set to high)
    await Timer(duration_ns, units="ns")  # Hold reset high for the specified duration
    await Timer(1, units="ns")

    # Verify that outputs are zero during reset
    assert dut.out.value == 0, f"[ERROR] out is not zero during reset: {dut.out.value}"

    dut.srst.value = 0  # Deactivate reset (set to low)
    await Timer(duration_ns, units='ns')  # Wait for the reset to stabilize
    dut.srst._log.debug("Reset complete")

def weighted_random_input(num_inputs):
    """
    Generate weighted random inputs.

    Args:
        num_inputs: Number of input bits.

    Returns:
        An integer representing the input vector.
    """
    if random.random() < 0.6:  # 60% chance to generate all 0's or all 1's
        return 0 if random.random() < 0.5 else (1 << num_inputs) - 1
    else:  # 40% chance to generate other combinations
        return random.randint(0, (1 << num_inputs) - 1)


@cocotb.test()
async def test_sync_muller_c_element(dut):
  """
  Verify the functionality of the sync_muller_c_element module with weighted random input vectors.

  Test Steps:
  1. Perform a synchronous reset.
  2. Drive the DUT with weighted random inputs.
  3. Verify correctness of the output based on input logic.
  4. Cover scenarios including reset and stable input combinations.
  """

  # Start the clock with a 10ns period
  cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

  # Initialize DUT inputs
  await hrs_lb.dut_init(dut)

  # Apply reset to DUT
  await reset_dut(dut)

  # Wait for a few clock cycles to ensure proper initialization
  for k in range(10):
    await RisingEdge(dut.clk)

  # Retrieve DUT configuration parameters
  num_inputs = int(dut.NUM_INPUT.value)
  pipe_depth = int(dut.PIPE_DEPTH.value)
  num_samples = 20

  # Print parameters for debugging
  print(f"NUM_INPUT: {num_inputs}")
  print(f"PIPE_DEPTH: {pipe_depth}")

  # Test with weighted random input vectors
  in_queue = []
  out_queue = []
  dut.clk_en.value = 1

  for i in range(num_samples):
    # Generate a random input
    random_input = weighted_random_input(num_inputs)
    dut.inp.value = random_input
    # Add input to the queue for later verification
    in_queue.append(random_input)
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    out = int(dut.out.value)
    out_queue.append(out)

  # Handle pipeline delay outputs
  for i in range(pipe_depth):
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    out = int(dut.out.value)
    out_queue.append(out)

  # Remove outputs corresponding to initial pipeline latency
  for i in range(pipe_depth):
    prev_out = out_queue.pop(0)

  # Perform verification of DUT outputs
  for i in range(num_samples):
    # Retrieve the input and output from the queues
    in_temp = in_queue.pop(0)
    out_temp = out_queue.pop(0)
    
    # Compute the expected output
    all_high = (1 << num_inputs) - 1
    all_low  = 0

    expected_output = 1 if (in_temp == all_high) else (0 if (in_temp == all_low) else prev_out)

    # Verify that the DUT output matches the expected output
    assert out_temp == expected_output, f"Test {i+1}: Output does not match the expected result: {out_temp} != {expected_output}"

    print(f"Test {i+1} passed")
    prev_out = out_temp

  # Wait for a few cycles before performing a final reset
  for k in range(2):
    await RisingEdge(dut.clk)

  # Apply a final reset to the DUT
  await reset_dut(dut)

  # Wait for a few cycles after reset to stabilize
  for k in range(2):
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_sync_muller_c_element_with_clk_en_toggle(dut):
  """
  Verify the functionality of sync_muller_c_element with clock enable toggling.

  Test Steps:
  1. Perform a synchronous reset.
  2. Toggle clock enable at specific intervals.
  3. Drive inputs and verify outputs during enabled and disabled periods.
  """

  # Start the clock with a 10ns period
  cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

  # Initialize DUT inputs
  await hrs_lb.dut_init(dut)

  # Apply reset to DUT
  await reset_dut(dut)

  # Wait for a few clock cycles to ensure proper initialization
  for k in range(10):
    await RisingEdge(dut.clk)

  # Retrieve DUT configuration parameters
  num_inputs = int(dut.NUM_INPUT.value)
  pipe_depth = int(dut.PIPE_DEPTH.value)
  num_samples = 30

  # Print parameters for debugging
  print(f"NUM_INPUT: {num_inputs}")
  print(f"PIPE_DEPTH: {pipe_depth}")

  # Test with clock enable toggle
  in_queue = []
  out_queue = []
  clk_en = 1
  dut.clk_en.value = clk_en

  for i in range(num_samples):

    if (i  == 10):
      clk_en = 0
    elif (i  == 20):
      clk_en = 1

    dut.clk_en.value = clk_en

    # Generate a random input
    random_input = weighted_random_input(num_inputs)
    dut.inp.value = random_input
    # Add input to the queue for later verification
    if (clk_en):
      in_queue.append(random_input)

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    out = int(dut.out.value)
    out_queue.append(out)

  # Handle pipeline delay outputs
  for i in range(pipe_depth):
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    out = int(dut.out.value)
    out_queue.append(out)

  # Remove outputs corresponding to initial pipeline latency
  for i in range(pipe_depth):
    prev_out = out_queue.pop(0)

  # Perform verification of DUT outputs
  for i in range(num_samples):
    if (i >= (10 - pipe_depth) and i <= (19 - pipe_depth)):
      expected_output = prev_out
      out_temp = out_queue.pop(0)
    else:
      # Retrieve the input and output from the queues
      in_temp = in_queue.pop(0)
      out_temp = out_queue.pop(0)
      
      # Compute the expected output
      all_high = (1 << num_inputs) - 1
      all_low  = 0
      expected_output = 1 if (in_temp == all_high) else (0 if (in_temp == all_low) else prev_out)

    # Verify that the DUT output matches the expected output
    assert out_temp == expected_output, f"Test {i+1}: Output does not match the expected result: {out_temp} != {expected_output}"

    print(f"Test {i+1} passed")
    prev_out = out_temp

  # Wait for a few cycles before performing a final reset
  for k in range(2):
    await RisingEdge(dut.clk)

  # Apply a final reset to the DUT
  await reset_dut(dut)

  # Wait for a few cycles after reset to stabilize
  for k in range(2):
    await RisingEdge(dut.clk)



@cocotb.test()
async def test_sync_muller_c_element_with_clr_toggle(dut):
  """
  Verify the functionality of sync_muller_c_element with clear signal toggling.

  Test Steps:
  1. Perform a synchronous reset.
  2. Drive inputs with random data.
  3. Toggle the clear signal and verify output behavior.
  """

  # Start the clock with a 10ns period
  cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

  # Initialize DUT inputs
  await hrs_lb.dut_init(dut)

  # Apply reset to DUT
  await reset_dut(dut)

  # Wait for a few clock cycles to ensure proper initialization
  for k in range(10):
    await RisingEdge(dut.clk)

  # Retrieve DUT configuration parameters
  num_inputs = int(dut.NUM_INPUT.value)
  pipe_depth = int(dut.PIPE_DEPTH.value)
  num_samples = 30

  # Print parameters for debugging
  print(f"NUM_INPUT: {num_inputs}")
  print(f"PIPE_DEPTH: {pipe_depth}")

  # Test with clear signal toggling
  in_queue = []
  out_queue = []
  dut.clk_en.value = 1
  clr = 0
  dut.clr.value = clr

  for i in range(num_samples):
    # Generate a random input
    random_input = weighted_random_input(num_inputs)
    dut.inp.value = random_input
    # Add input to the queue for later verification
    in_queue.append(random_input)
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    out = int(dut.out.value)
    out_queue.append(out)
    if (i == 20):
      clr = 1
      dut.clr.value = clr

  # Handle pipeline delay outputs
  for i in range(pipe_depth):
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    out = int(dut.out.value)
    out_queue.append(out)

  # Remove outputs corresponding to initial pipeline latency
  for i in range(pipe_depth):
    prev_out = out_queue.pop(0)

  # Perform verification for DUT Outputs
  for i in range(num_samples):
    # Retrieve the input and output from the queues
    in_temp = in_queue.pop(0)
    out_temp = out_queue.pop(0)
    
    # Compute the expected output
    all_high = (1 << num_inputs) - 1
    all_low  = 0

    if (i > (20 - pipe_depth)):
      expected_output = 0
    else:
      expected_output = 1 if (in_temp == all_high) else (0 if (in_temp == all_low) else prev_out)

    # Verify that the DUT output matches the expected output
    assert out_temp == expected_output, f"Test {i+1}: Output does not match the expected result: {out_temp} != {expected_output}"

    print(f"Test {i+1} passed")
    prev_out = out_temp

  # Wait for a few cycles before performing a final reset
  for k in range(2):
    await RisingEdge(dut.clk)

  # Apply a final reset to the DUT
  await reset_dut(dut)

  # Wait for a few cycles after reset to stabilize
  for k in range(2):
    await RisingEdge(dut.clk)