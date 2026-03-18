import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Predefined 12-bit value for testing
PREDEFINED_VALUE = 0b000110001101

async def initialize_dut(dut):
    """Initialize the DUT and start the clock."""
    dut.reset_in.value = 1
    dut.ir_signal_in.value = 1

    # Start the 50 MHz clock (period = 20 ns)
    clock = Clock(dut.clk_in, 1000, units="ns")
    cocotb.start_soon(clock.start())

    # Wait for reset propagation
    await Timer(100, units="ns")
    dut.reset_in.value = 0

async def send_ir_signal(dut, predefined_value):
    """Send the IR signal to the DUT."""
    # Start bit: 2.4 ms LOW
    dut.ir_signal_in.value = 1
    await Timer(2400000, units="ns")

    # Send predefined 12-bit value bit by bit
    for i in range(11, -1, -1):
        dut.ir_signal_in.value = 0
        await Timer(600000, units="ns")  # 0.6 ms LOW

        if (predefined_value >> i) & 1:
            dut.ir_signal_in.value = 1
            await Timer(1200000, units="ns")  # 1.2 ms HIGH for '1'
        else:
            dut.ir_signal_in.value = 1
            await Timer(600000, units="ns")  # 0.6 ms HIGH for '0'

    # End of transmission: 0.6 ms LOW
    dut.ir_signal_in.value = 0
    #await Timer(600000, units="ns")

def reverse_bits(value, bit_width=12):
    """Reverse the bits of a given value."""
    reversed_value = 0
    for i in range(bit_width):
        if (value >> i) & 1:
            reversed_value |= 1 << (bit_width - 1 - i)
    return reversed_value

@cocotb.test()
async def test_ir_receiver(dut):
    """Test the IR receiver DUT."""
    # Initialize the DUT
    await initialize_dut(dut)

    # Send the IR signal
    await send_ir_signal(dut, PREDEFINED_VALUE)

    # Wait for the DUT to process the signal
    await Timer(1000, units="ns")

    # Reverse the predefined value for comparison
    reversed_predefined_value = reverse_bits(PREDEFINED_VALUE)

    # Check the output frame
    await RisingEdge(dut.ir_frame_valid)
    received_frame = int(dut.ir_frame_out.value)
    valid = dut.ir_frame_valid.value
    dut._log.info(f"Expected: {reversed_predefined_value:012b}, Received: {received_frame:012b}, Valid: {valid}")
    if received_frame == reversed_predefined_value:
        dut._log.info("Test Passed: Frame matches the predefined value.")
    else:
        dut._log.error(f"Test Failed: Frame does not match the predefined value. "
                       f"Expected: {reversed_predefined_value:012b}, "
                       f"Received: {received_frame:012b}")

    # End simulation
    dut._log.info("Simulation Complete")

@cocotb.test()
async def test_reset_behavior(dut):
    """Test the DUT's behavior during and after reset."""
    # Initialize the DUT
    await initialize_dut(dut)

    # Check outputs are reset
    received_frame = int(dut.ir_frame_out.value)
    valid = dut.ir_frame_valid.value
    dut._log.info(f"Expected: 000000000000, Received: {received_frame:012b}, Valid: {valid}")
    assert received_frame == 0, "IR frame should be 0 after reset"
    assert valid == 0, "Frame valid should be 0 after reset"

    dut._log.info("Reset behavior test passed.")

@cocotb.test()
async def test_edge_case_invalid_start(dut):
    """Test how the DUT handles an invalid signal."""
    # Initialize the DUT
    await initialize_dut(dut)

    # Send an invalid signal (missing start pulse)
    for _ in range(10):
        dut.ir_signal_in.value = 0
        await Timer(600000, units="ns")  # 0.6 ms LOW

    # Wait for the DUT to process
    await Timer(1000, units="ns")

    # Validate output
    received_frame = int(dut.ir_frame_out.value)
    valid = dut.ir_frame_valid.value
    dut._log.info(f"Expected: 000000000000, Received: {received_frame:012b}, Valid: {valid}")
    assert received_frame == 0, "IR frame should remain 0 for invalid signal"
    assert valid == 0, "Frame valid should remain low for invalid signal"

    dut._log.info("Invalid signal test passed.")

@cocotb.test()
async def test_ir_receiver_random_input(dut):
    """Test the IR receiver DUT with random data."""
    import random

    # Initialize the DUT
    await initialize_dut(dut)

    # Generate a random 12-bit value
    random_value = random.randint(0, 2**12 - 1)

    # Send the IR signal
    await send_ir_signal(dut, random_value)

    # Wait for the DUT to process the signal
    await Timer(1000, units="ns")

    # Reverse the random value for comparison
    reversed_random_value = reverse_bits(random_value)

    # Check the output frame
    await RisingEdge(dut.ir_frame_valid)
    received_frame = int(dut.ir_frame_out.value)
    valid = dut.ir_frame_valid.value
    dut._log.info(f"Expected: {reversed_random_value:012b}, Received: {received_frame:012b}, Valid: {valid}")
    if received_frame == reversed_random_value:
        dut._log.info("Test Passed: Frame matches the random value.")
    else:
        dut._log.error(f"Test Failed: Frame does not match the random value. "
                       f"Expected: {reversed_random_value:012b}, "
                       f"Received: {received_frame:012b}")

    # End simulation
    dut._log.info("Simulation Complete")

@cocotb.test()
async def test_edge_case_bit_timing(dut):
    """Test edge cases like very short and very long pulses."""
    # Initialize the DUT
    await initialize_dut(dut)

    # Very short pulses
    for _ in range(5):
        dut.ir_signal_in.value = 0
        await Timer(100, units="ns")  # Very short LOW pulse
        dut.ir_signal_in.value = 1
        await Timer(100, units="ns")  # Very short HIGH pulse

    # Wait for the DUT to process
    await Timer(1000, units="ns")

    # Validate output
    received_frame = int(dut.ir_frame_out.value)
    valid = dut.ir_frame_valid.value
    dut._log.info(f"Expected: 000000000000, Received: {received_frame:012b}, Valid: {valid}")
    assert received_frame == 0, "IR frame should remain 0 for invalid short pulses"
    assert valid == 0, "Frame valid should remain low for invalid short pulses"

    # Very long pulses
    dut.ir_signal_in.value = 0
    await Timer(10000000, units="ns")  # Very long LOW pulse
    dut.ir_signal_in.value = 1
    await Timer(10000000, units="ns")  # Very long HIGH pulse

    # Wait for the DUT to process
    await Timer(1000, units="ns")

    # Validate output
    received_frame = int(dut.ir_frame_out.value)
    valid = dut.ir_frame_valid.value
    dut._log.info(f"Expected: 000000000000, Received: {received_frame:012b}, Valid: {valid}")
    assert received_frame == 0, "IR frame should remain 0 for invalid long pulses"
    assert valid == 0, "Frame valid should remain low for invalid long pulses"

    dut._log.info("Edge cases test passed.")

