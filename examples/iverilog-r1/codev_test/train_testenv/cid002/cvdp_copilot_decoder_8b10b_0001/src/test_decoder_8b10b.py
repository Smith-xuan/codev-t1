import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from collections import deque

# Special character code values
K28d0_RD0 = "0011110100"
K28d0_RD1 = "1100001011"
K28d1_RD0 = "0011111001"
K28d1_RD1 = "1100000110"
K28d2_RD0 = "0011110101"
K28d2_RD1 = "1100001010"
K28d3_RD0 = "0011110011"
K28d3_RD1 = "1100001100"
K28d4_RD0 = "0011110010"
K28d4_RD1 = "1100001101"
K28d5_RD0 = "0011111010"
K28d5_RD1 = "1100000101"
K28d6_RD0 = "0011110110"
K28d6_RD1 = "1100001001"
K28d7_RD0 = "0011111000"
K28d7_RD1 = "1100000111"
K23d7_RD0 = "1110101000"
K23d7_RD1 = "0001010111"
K27d7_RD0 = "1101101000"
K27d7_RD1 = "0010010111"
K29d7_RD0 = "1011101000"
K29d7_RD1 = "0100010111"
K30d7_RD0 = "0111101000"
K30d7_RD1 = "1000010111"

async def initialize_dut(dut):
    """Initialize the DUT and start the clock."""
    dut.reset_in.value = 1
    dut.decoder_in.value = 0

    clock = Clock(dut.clk_in, 50, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    dut.reset_in.value = 0

async def check_output(dut, expected_value, expected_control, input_value):
    """Check the output of the DUT against the expected value."""
    expected_value_bin = f"{int(expected_value, 16):08b}"  # Convert hex to binary
    print(f"Expected: {hex(int(expected_value, 16)):>4}, Got: {hex(int(dut.decoder_out.value.binstr, 2)):>4}, Input: {input_value}")
    assert dut.decoder_out.value.binstr == expected_value_bin, f"Expected {expected_value_bin}, got {dut.decoder_out.value.binstr}"
    assert dut.control_out.value == expected_control, f"Expected control {expected_control}, got {dut.control_out.value}"

def calculate_expected_value(codeword):
    """Calculate the expected value based on the 10-bit codeword."""
    if codeword in [K28d0_RD0, K28d0_RD1]:
        return "1C"
    elif codeword in [K28d1_RD0, K28d1_RD1]:
        return "3C"
    elif codeword in [K28d2_RD0, K28d2_RD1]:
        return "5C"
    elif codeword in [K28d3_RD0, K28d3_RD1]:
        return "7C"
    elif codeword in [K28d4_RD0, K28d4_RD1]:
        return "9C"
    elif codeword in [K28d5_RD0, K28d5_RD1]:
        return "BC"
    elif codeword in [K28d6_RD0, K28d6_RD1]:
        return "DC"
    elif codeword in [K28d7_RD0, K28d7_RD1]:
        return "FC"
    elif codeword in [K23d7_RD0, K23d7_RD1]:
        return "F7"
    elif codeword in [K27d7_RD0, K27d7_RD1]:
        return "FB"
    elif codeword in [K29d7_RD0, K29d7_RD1]:
        return "FD"
    elif codeword in [K30d7_RD0, K30d7_RD1]:
        return "FE"
    else:
        return "00"

@cocotb.test()
async def test_decoder_8b10b_reset(dut):
    """Test sending any random control symbol continuously out of 12 symbols and reset HIGH."""
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(10):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        print(f"Delayed decoder_in: {delayed_decoder_in}")  # Debug print

        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

    dut.reset_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    expected_value = "00"
    expected_control = 0
    await check_output(dut, expected_value, expected_control, "0000000000")

@cocotb.test()
async def test_continuous_control_symbol(dut):
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(28):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

    await Timer(100, units="ns")


@cocotb.test()
async def test_random_control_symbol(dut):
    """Test sending any random control symbol continuously out of 12 symbols."""
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(10):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

@cocotb.test()
async def test_same_control_symbol(dut):
    """Test sending the same control symbol continuously."""
    await initialize_dut(dut)

    control_symbols = [K28d6_RD0, K28d6_RD1]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(20):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

@cocotb.test()
async def test_random_invalid_control_input(dut):
    """Test sending any 10-bit input other than 12 control symbols."""
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(10):  # Adjust the range as needed
        random_data = random.randint(0, 1023)
        while f"{random_data:010b}" in control_symbols:
            random_data = random.randint(0, 1023)
        dut.decoder_in.value = random_data
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

    await Timer(100, units="ns")
