import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

# Parameters
A_DW = 8
B_DW = 16
OUT_DW = 32
random.seed(42)  # Ensures reproducibility of random values

async def initialize_dut(dut):
    """Initialize the DUT and start the clock."""
    dut.reset_in.value = 1
    dut.start_in.value = 0
    dut.vector_a_valid_in.value = 0
    dut.vector_b_valid_in.value = 0
    dut.dot_length_in.value = 0

    # Start the clock
    clock = Clock(dut.clk_in, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset propagation
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.reset_in.value = 0
    dut._log.info("DUT Initialized: Reset Deasserted.")

async def send_vector(dut, vec_a, vec_b, length):
    """Send vector inputs to the DUT."""
    dut.dot_length_in.value = length
    await RisingEdge(dut.clk_in)
    dut.start_in.value = 1

    dut._log.info(f"Sending Vectors: Length = {length}")
    for i in range(length):
        await RisingEdge(dut.clk_in)
        dut.start_in.value = 0
        dut.vector_a_in.value = vec_a[i]
        dut.vector_b_in.value = vec_b[i]
        dut.vector_a_valid_in.value = 1
        dut.vector_b_valid_in.value = 1

        dut._log.info(f"Input Vectors: vector_a_in = {vec_a[i]}, vector_b_in = {vec_b[i]}, Valid = {dut.vector_a_valid_in.value}")

    await RisingEdge(dut.clk_in)
    dut.vector_a_valid_in.value = 0
    dut.vector_b_valid_in.value = 0

async def check_result(dut, expected_result):
    """Check the DUT result and validate correctness."""
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    valid = int(dut.dot_product_valid_out.value)
    result = int(dut.dot_product_out.value)

    dut._log.info(f"DUT Output: result = {result}, valid = {valid}")

    if valid:
        if result != expected_result:
            dut._log.error(f"Result mismatch! Expected: {expected_result}, Got: {result}")
            assert False
        else:
            dut._log.info(f"Result matches expected value: {expected_result}")
    else:
        dut._log.error("Unexpected state: valid_out is not asserted.")
        assert False

@cocotb.test()
async def test_case_reset_assert(dut):
    """Test Case: Reset behavior during computation."""
    await initialize_dut(dut)

    vec_a = [1, 1, 1, 1]
    vec_b = [1, 2, 3, 4]

    await send_vector(dut, vec_a, vec_b, 4)

    # Assert reset during computation
    dut.reset_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    # Print inputs and outputs after reset is asserted
    dut._log.info(f"Inputs after reset: vector_a_in = {dut.vector_a_in.value}, vector_b_in = {dut.vector_b_in.value}")
    dut._log.info(f"Outputs after reset: dot_product_out = {dut.dot_product_out.value}, dot_product_valid_out = {dut.dot_product_valid_out.value}")

    # Check that the outputs are reset to 0
    assert dut.dot_product_out.value == 0, f"dot_product_out expected to be 0, got {int(dut.dot_product_out.value)}"
    assert dut.dot_product_valid_out.value == 0, "dot_product_valid_out expected to be 0, but it is HIGH"

    dut._log.info("Reset behavior verified: Outputs reset to 0 as expected.")

@cocotb.test()
async def test_case_length_4(dut):
    """Test Case : Length 4."""
    await initialize_dut(dut)

    vec_a = [1, 1, 1, 1]
    vec_b = [1, 2, 3, 4]
    expected_result = sum(a * b for a, b in zip(vec_a, vec_b))

    await send_vector(dut, vec_a, vec_b, 4)
    await check_result(dut, expected_result)

@cocotb.test()
async def test_case_length_8(dut):
    """Test Case : Length 8."""
    await initialize_dut(dut)

    vec_a = [2] * 8
    vec_b = [i + 1 for i in range(8)]
    expected_result = sum(a * b for a, b in zip(vec_a, vec_b))

    await send_vector(dut, vec_a, vec_b, 8)
    await check_result(dut, expected_result)

@cocotb.test()
async def test_case_random_length_6(dut):
    """Test Case : Random Length 6."""
    await initialize_dut(dut)

    vec_a = [random.randint(0, 255) for _ in range(6)]
    vec_b = [random.randint(0, 65535) for _ in range(6)]
    expected_result = sum(a * b for a, b in zip(vec_a, vec_b))

    await send_vector(dut, vec_a, vec_b, 6)
    await check_result(dut, expected_result)

@cocotb.test()
async def test_case_random_length_127(dut):
    """Test Case : Random Length 127."""
    await initialize_dut(dut)

    vec_a = [random.randint(0, 255) for _ in range(127)]
    vec_b = [random.randint(0, 65535) for _ in range(127)]
    expected_result = sum(a * b for a, b in zip(vec_a, vec_b))

    await send_vector(dut, vec_a, vec_b, 127)
    await check_result(dut, expected_result)

@cocotb.test()
async def test_case_random_length_99(dut):
    """Test Case : Random Length 99."""
    await initialize_dut(dut)

    vec_a = [random.randint(0, 255) for _ in range(99)]
    vec_b = [random.randint(0, 65535) for _ in range(99)]
    expected_result = sum(a * b for a, b in zip(vec_a, vec_b))

    await send_vector(dut, vec_a, vec_b, 99)
    await check_result(dut, expected_result)

@cocotb.test()
async def test_case_random_vectors_and_length(dut):
    """Test Case : Random Length."""
    await initialize_dut(dut)

    # Generate a random length between 1 and 99
    length = random.randint(1, 127)

    # Generate random input vectors of the determined length
    vec_a = [random.randint(0, 255) for _ in range(length)]
    vec_b = [random.randint(0, 65535) for _ in range(length)]
    expected_result = sum(a * b for a, b in zip(vec_a, vec_b))

    dut._log.info(f"Random Length: {length}")

    await send_vector(dut, vec_a, vec_b, length)
    await check_result(dut, expected_result)


