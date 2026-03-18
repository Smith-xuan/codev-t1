import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import harness_library as hrs_lb
import math

# ----------------------------------------
# - Write Buffer Merge Test
# ----------------------------------------

async def reset_dut(dut, duration_ns=10):
  """
    Reset the DUT by setting the synchronous reset signal high for a specified duration
    and then setting it low again.

    During reset, ensure that the DUT's outputs are zero.

    Args:
        dut: The Design Under Test (DUT).
        duration_ns: The time duration in nanoseconds for which the reset signal will be held high.
    """
  dut.srst.value = 1  # Set reset to active high
  await Timer(duration_ns, units="ns")  # Wait for the specified duration

  # Ensure all outputs are zero
  assert dut.wr_en_out.value == 0, f"[ERROR] wr_en_out is not zero after reset: {dut.wr_en_out.value}"
  assert dut.wr_addr_out.value == 0, f"[ERROR] wr_addr_out is not zero after reset: {dut.wr_addr_out.value}"
  assert dut.wr_data_out.value == 0, f"[ERROR] wr_data_out is not zero after reset: {dut.wr_data_out.value}"

  dut.srst.value = 0  # Deactivate reset (set it low)
  await Timer(duration_ns, units='ns')  # Wait for the reset to stabilize
  dut.srst._log.debug("Reset complete")


@cocotb.test()
async def verify_write_buffer_merge(dut):
  """
  Verify the write buffer merge functionality.
  This test checks for the following:
  - Proper buffering and merging of input data.
  - Correct output address and data generation.
  - Proper signaling of `wr_en_out` when the buffer is full.
  - Handling of resets.

  The test dynamically generates random inputs, tracks expected outputs, 
  and verifies the DUT outputs against expected results.
  """

  # Start the clock with a 2ns period
  cocotb.start_soon(Clock(dut.clk, 2, units='ns').start())

  # Initialize DUT inputs
  await hrs_lb.dut_init(dut)

  # Apply reset to DUT
  await reset_dut(dut)

  # Wait for a few cycles to stabilize
  for k in range(10):
    await RisingEdge(dut.clk)

  # Retrieve parameters from the DUT
  input_data_width = int(dut.INPUT_DATA_WIDTH.value)
  input_addr_width = int(dut.INPUT_ADDR_WIDTH.value)
  buffer_depth = int(dut.BUFFER_DEPTH.value)
  output_data_width = int(dut.OUTPUT_DATA_WIDTH.value)
  output_addr_width = int(dut.OUTPUT_ADDR_WIDTH.value)

  # Number of outputs and inputs based on buffer depth
  num_outputs = random.randint(1, 16) 
  num_inputs = num_outputs*buffer_depth
  continuous_input = random.randint(0, 1)


  # Print paramerters for debugging
  print(f"INPUT_DATA_WIDTH: {input_data_width}")
  print(f"INPUT_ADDR_WIDTH: {input_addr_width}")
  print(f"BUFFER_DEPTH: {buffer_depth}")
  print(f"NUM_OUTPUTS: {num_outputs}")
  
  # Initialize variables for tracking inputs and outputs
  i = 0
  data_in_queue = []
  addr_in_queue = []

  data_out_queue = []
  addr_out_queue = []
  num_outputs_from_dut = 0

  prev_wr_data_out = 0
  prev_wr_addr_out = 0
  out_latency = 0

  # Dynamically generate and apply inputs
  while i < num_inputs:
    # Generate random inputs
    if continuous_input == 1:
      wr_en_in = 1
    else:
      wr_en_in = random.randint(0, 1)
    wr_data_in = random.randint(0, (1<<input_data_width)-1)
    if (wr_en_in == 1):
      if ((i%buffer_depth) == 0):
        # Generate aligned addresses based on buffer depth
        wr_addr_in = buffer_depth*((random.randint(0, ((1<<input_addr_width)-1)))//buffer_depth)
      else:
        wr_addr_in = wr_addr_in + 1

      # Assign the values to DUT inputs
      dut.wr_en_in.value = wr_en_in
      dut.wr_data_in.value = wr_data_in
      dut.wr_addr_in.value = wr_addr_in

      # Store the input for later verification
      i+=1
      data_in_queue.append(wr_data_in)
      if ((i%buffer_depth) == 0):
        addr_in_queue.append(wr_addr_in)

    await RisingEdge(dut.clk)

    # Capture DUT outputs
    wr_en_out = int(dut.wr_en_out.value)
    wr_data_out = int(dut.wr_data_out.value)
    wr_addr_out = int(dut.wr_addr_out.value)
    if (wr_en_out == 1):
      data_out_queue.append(wr_data_out)
      addr_out_queue.append(wr_addr_out)
      num_outputs_from_dut+=1
    else:
      assert wr_addr_out == prev_wr_addr_out, f"[ERROR] Output Address Changed when Write Enable Out is Low Prev={prev_wr_addr_out}, Current={wr_addr_out}"
      assert wr_data_out == prev_wr_data_out, f"[ERROR] Output Data Changed when Write Enable Out is Low Prev={prev_wr_data_out}, Current={wr_data_out}"

    prev_wr_data_out = wr_data_out
    prev_wr_addr_out = wr_addr_out

    if (wr_en_out == 1):
      if (buffer_depth == 1):
        assert out_latency == 1, f"[ERROR] Output Latency Mismatch Expected=1, Current={out_latency}"
      else:
        assert out_latency == 2, f"[ERROR] Output Latency Mismatch Expected=2, Current={out_latency}"
      out_latency = 0

    if (wr_en_in & (((i-1)%buffer_depth) == (buffer_depth-1))):
      out_latency = 1
    elif (out_latency >= 1):
      out_latency += 1

    # Set wr_en_in low
    dut.wr_en_in.value = 0

  print(f"All inputs have been generated!")

  await RisingEdge(dut.clk)
  # Wait for remaining outputs from the DUT
  while num_outputs_from_dut < num_outputs:
    wr_en_out = int(dut.wr_en_out.value)
    wr_data_out = int(dut.wr_data_out.value)
    wr_addr_out = int(dut.wr_addr_out.value)
    if (wr_en_out == 1):
      data_out_queue.append(wr_data_out)
      addr_out_queue.append(wr_addr_out)
      num_outputs_from_dut+=1
    await RisingEdge(dut.clk)

  print(f"All outputs have been received!")

  # Verify outputs against expected values
  for i in range(num_outputs):
    expected_data = 0
    expected_addr = addr_in_queue.pop(0) >> math.ceil(math.log2(buffer_depth));
    for j in range(buffer_depth):
      expected_data |= (data_in_queue.pop(0) << (j * input_data_width))

    rtl_addr = addr_out_queue.pop(0)
    rtl_data = data_out_queue.pop(0)


    # Verify address output
    assert rtl_addr == expected_addr, f"[ERROR] Output {i+1}: Address mismatch! Expected={expected_addr}, Got={rtl_addr}"

    # Verify data output
    assert rtl_data == expected_data, f"[ERROR] Output {i+1}: Data mismatch! Expected={expected_data}, Got={rtl_data}"

    print(f"Output {i+1} Matched")

  # Wait for 2 cycles
  for k in range(2):
    await RisingEdge(dut.clk)

  # Apply reset to DUT
  await reset_dut(dut)

  # Wait for 2 cycles
  for k in range(2):
    await RisingEdge(dut.clk)

