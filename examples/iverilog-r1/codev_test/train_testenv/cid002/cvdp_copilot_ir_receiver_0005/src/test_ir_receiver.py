import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

def calculate_reference_value(predefined_seq):
    """Calculate the expected reference value based on the input frame."""
    if predefined_seq & 0x7F < 10:  # For values less than 10
        if (predefined_seq & 0x7F) == 9:
            ref_value = ((1 << ((predefined_seq >> 7) & 0x1F)) << 7)
        else:
            ref_value = ((1 << ((predefined_seq >> 7) & 0x1F)) << 7) | ((predefined_seq & 0x7F) + 1)
    elif 16 <= (predefined_seq & 0x7F) < 23:  # For values between 16 and 23
        test_bits = (predefined_seq & 0x7F) - 15
        ref_value = ((1 << ((predefined_seq >> 7) & 0x1F)) << 7) | (test_bits << 4) | 0xF
    else:
        ref_value = 0  # Default value if conditions are not met
    return ref_value

async def initialize_dut(dut):
    """Initialize the DUT and start the clock."""
    dut.reset_in.value = 1
    dut.ir_signal_in.value = 1

    # Start the 50 MHz clock (period = 20 ns)
    clock = Clock(dut.clk_in, 100000, units="ns")
    cocotb.start_soon(clock.start())

    # Wait for reset propagation
    await Timer(200000, units="ns")
    dut.reset_in.value = 0

async def send_ir_signal(dut, predefined_value):
    """Send the IR signal to the DUT."""
    # Start bit: 2.4 ms LOW
    dut.ir_signal_in.value = 1
    await Timer(2400000, units="ns")

    for i in range(12):
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

async def run_test_case(dut, address):
    """Run a test case for a specific 5-bit address."""
    await initialize_dut(dut)

    for function in range(10):  # Loop through 7-bit function codes (0 to 16)
        predefined_value = (address << 7) | function  # Combine address and function
        reference_value = calculate_reference_value(predefined_value)

        # Send the IR signal
        await send_ir_signal(dut, predefined_value)

        # Wait for the DUT to process the signal
        await Timer(100000, units="ns")
        await Timer(100000, units="ns")
        await Timer(100000, units="ns")

        received_frame = (int(dut.ir_device_address_out.value) << 7) | int(dut.ir_function_code_out.value)

        dut._log.info(f"Predefined: {predefined_value:012b}, Expected: {reference_value:012b}, Received: {received_frame:012b}")
        assert received_frame == reference_value, (
            f"Test Failed: Predefined = {predefined_value:012b}, "
            f"Expected = {reference_value:012b}, Received = {received_frame:012b}"
        )
        await Timer(40000000, units="ns")  # 0.6 ms HIGH for '0'

    for function in range(16, 23):  # Loop through 7-bit function codes (0 to 16)
        predefined_value = (address << 7) | function  # Combine address and function
        reference_value = calculate_reference_value(predefined_value)

        # Send the IR signal
        await send_ir_signal(dut, predefined_value)

        # Wait for the DUT to process the signal
        await Timer(100000, units="ns")
        await Timer(100000, units="ns")
        await Timer(100000, units="ns")

        received_frame = (int(dut.ir_device_address_out.value) << 7) | int(dut.ir_function_code_out.value)

        dut._log.info(f"Predefined: {predefined_value:012b}, Expected: {reference_value:012b}, Received: {received_frame:012b}")
        assert received_frame == reference_value, (
            f"Test Failed: Predefined = {predefined_value:012b}, "
            f"Expected = {reference_value:012b}, Received = {received_frame:012b}"
        )
        await Timer(40000000, units="ns")  # 0.6 ms HIGH for '0'

    dut._log.info(f"Test Case for Address {address:05b} passed successfully.")

@cocotb.test()
async def test_ir_receiver_address_00000(dut):
    """Test Case: Address 5'b00000 with all valid 7-bit function combinations."""
    await run_test_case(dut, address=0b00000)


@cocotb.test()
async def test_ir_receiver_address_00001(dut):
    """Test Case: Address 5'b00001 with all valid 7-bit function combinations."""
    await run_test_case(dut, address=0b00001)


@cocotb.test()
async def test_ir_receiver_address_00010(dut):
    """Test Case: Address 5'b00010 with all valid 7-bit function combinations."""
    await run_test_case(dut, address=0b00010)

@cocotb.test()
async def test_ir_receiver_address_00011(dut):
    """Test Case: Address 5'b00011 with all valid 7-bit function combinations."""
    await run_test_case(dut, address=0b00011)


@cocotb.test()
async def test_ir_receiver_address_00100(dut):
    """Test Case: Address 5'b00100 with all valid 7-bit function combinations."""
    await run_test_case(dut, address=0b00100)

@cocotb.test()
async def test_ir_received_random_input(dut):
    """Run a test case for a random IR 12-bit frame."""
    await initialize_dut(dut)

    for _ in range(10):  # Run 10 random tests for this address
        function = random.choice(range(10))  # Randomly choose a valid function code (0 to 9)
        address = random.choice(range(5))  # Randomly choose a valid address (0 to 4)
        predefined_value = (address << 7) | function  # Combine address and function
        reference_value = calculate_reference_value(predefined_value)

        # Send the IR signal
        await send_ir_signal(dut, predefined_value)

        # Wait for the DUT to process the signal
        await Timer(300000, units="ns")  # Process delay

        # Check the output frame
        received_frame = (int(dut.ir_device_address_out.value) << 7) | int(dut.ir_function_code_out.value)
        dut._log.info(f"Predefined: {predefined_value:012b}, Expected: {reference_value:012b}, Received: {received_frame:012b}")
        assert received_frame == reference_value, (
            f"Test Failed: Predefined = {predefined_value:012b}, "
            f"Expected = {reference_value:012b}, Received = {received_frame:012b}"
        )

        await Timer(40000000, units="ns")  # Wait before the next signal

    for _ in range(16, 23):  # Run 10 random tests for this address
        function = random.choice(range(10))  # Randomly choose a valid function code (0 to 9)
        address = random.choice(range(5))  # Randomly choose a valid address (0 to 4)
        predefined_value = (address << 7) | function  # Combine address and function
        reference_value = calculate_reference_value(predefined_value)

        # Send the IR signal
        await send_ir_signal(dut, predefined_value)

        # Wait for the DUT to process the signal
        await Timer(300000, units="ns")  # Process delay

        # Check the output frame
        received_frame = (int(dut.ir_device_address_out.value) << 7) | int(dut.ir_function_code_out.value)
        dut._log.info(f"Predefined: {predefined_value:012b}, Expected: {reference_value:012b}, Received: {received_frame:012b}")
        assert received_frame == reference_value, (
            f"Test Failed: Predefined = {predefined_value:012b}, "
            f"Expected = {reference_value:012b}, Received = {received_frame:012b}"
        )

        await Timer(40000000, units="ns")  # Wait before the next signal

    dut._log.info(f"Test Case for Address {address:05b} passed successfully.")

@cocotb.test()
async def test_reset_behavior(dut):
    """Test the DUT's behavior during and after reset."""
    # Initialize the DUT
    await initialize_dut(dut)
    await RisingEdge(dut.clk_in) 
    dut.reset_in.value = 1

    # Check outputs are reset
    received_frame = (int(dut.ir_device_address_out.value) << 7) | int(dut.ir_function_code_out.value)
    valid = dut.ir_output_valid.value
    dut._log.info(f"Expected: 000000000000, Received: {received_frame:012b}, Valid: {valid}")
    assert received_frame == 0, "IR frame should be 0 after reset"
    assert valid == 0, "Frame valid should be 0 after reset"

    dut._log.info("Reset behavior test passed.")
