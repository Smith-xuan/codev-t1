import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

# Helper function to initialize DUT inputs
async def dut_initialization(dut):
    """ Initialize all inputs for DUT """
    dut.rst_in.value = 1
    dut.decoder_data_valid_in.value = 0
    dut.decoder_data_in.value = 0
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle

# Helper function to check the output with debug logging
async def check_output(dut, expected_data, expected_sync_error, expected_control_out=0, expected_decoder_error_out=0):
    """Check DUT output against expected values"""
    await RisingEdge(dut.clk_in)  # Wait for the output latency of 1 cycle
    actual_data_out = dut.decoder_data_out.value.integer
    actual_sync_error = dut.sync_error.value.integer
    actual_control_out = dut.decoder_control_out.value.integer
    actual_decoder_error_out = dut.decoder_error_out.value.integer
    decoder_data_in = dut.decoder_data_in.value.integer

    # Log the actual and expected outputs
    dut._log.info(f"Checking output - Input: {hex(decoder_data_in)},  Actual decoder_data_out: {hex(actual_data_out)}, Expected decoder_data_out: {hex(expected_data)}\n"
                  f"  Actual sync_error: {actual_sync_error}, Expected sync_error: {expected_sync_error}\n"
                  f"  Actual decoder_control_out: {hex(actual_control_out)}, Expected decoder_control_out: {hex(expected_control_out)}\n"
                  f"  Actual decoder_error_out: {actual_decoder_error_out}, Expected decoder_error_out: {expected_decoder_error_out}\n")

    # Always check sync_error and decoder_error_out
    assert actual_sync_error == expected_sync_error, \
        f"Sync error mismatch: sync_error={actual_sync_error} (expected {expected_sync_error})"
    assert actual_decoder_error_out == expected_decoder_error_out, \
        f"Decoder error mismatch: decoder_error_out={actual_decoder_error_out} (expected {expected_decoder_error_out})"

    # Check data and control output only if both sync_error and decoder_error_out are 0
    if expected_sync_error == 0 and expected_decoder_error_out == 0:
        assert actual_data_out == expected_data, \
            f"Data mismatch: decoder_data_out={hex(actual_data_out)} (expected {hex(expected_data)})"
        assert actual_control_out == expected_control_out, \
            f"Control output mismatch: decoder_control_out={hex(actual_control_out)} (expected {hex(expected_control_out)})"

@cocotb.test()
async def reset_test(dut):
    """ Test the reset behavior of the decoder """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Initialize DUT inputs
    await dut_initialization(dut)

    await Timer(20, units="ns")  # hold reset for 20ns
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    # Log the output after reset
    dut._log.info(f"Reset Test:\n  decoder_data_out: {hex(dut.decoder_data_out.value.integer)}\n  Expected: 0")

    # Check that output is zero after reset
    assert dut.decoder_data_out.value == 0, "Reset test failed: decoder_data_out should be zero after reset"
    assert dut.sync_error.value == 0, "Reset test failed: sync_error should be zero after reset"

@cocotb.test()
async def valid_data_test(dut):
    """ Test decoding when the sync header indicates valid data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Initialize DUT inputs
    await dut_initialization(dut)

    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Set test inputs
    dut.decoder_data_in.value = (0b01 << 64) | 0xA5A5A5A5A5A5A5A5
    dut.decoder_data_valid_in.value = 1

    await Timer(5, units="ns")
    # Apply test and check output
    await RisingEdge(dut.clk_in)
    dut.decoder_data_valid_in.value = 0
    dut._log.info(f"Valid Data Test:\n"
                  f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
    await check_output(dut, expected_data=0xA5A5A5A5A5A5A5A5, expected_sync_error=0)

@cocotb.test()
async def unsupported_control_test(dut):
    """ Test decoding when the sync header indicates unsupported control """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Set test inputs
    dut.decoder_data_in.value = (0b11 << 64) | 0xFFFFFFFFFFFFFFFF
    dut.decoder_data_valid_in.value = 1

    await Timer(5, units="ns")
    # Apply test and check output
    await RisingEdge(dut.clk_in)
    dut.decoder_data_valid_in.value = 0
    dut._log.info(f"Unsupported Control Test:\n"
                  f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
    await check_output(dut, expected_data=0x0000000000000000, expected_sync_error=1)

@cocotb.test()
async def invalid_sync_test(dut):
    """ Test decoding when the sync header is invalid """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Test with invalid sync headers
    for sync_header in [0b00, 0b11]:
        dut.decoder_data_in.value = (sync_header << 64) | 0x123456789ABCDEF0
        dut.decoder_data_valid_in.value = 1

        await Timer(5, units="ns")
        # Apply test and check output
        await RisingEdge(dut.clk_in)
        dut.decoder_data_valid_in.value = 0
        dut._log.info(f"Invalid Sync Test:\n"
                      f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
        await check_output(dut, expected_data=0x0000000000000000, expected_sync_error=1)

@cocotb.test()
async def random_any_sync_header_data_test(dut):
    """ Test decoding with random sync headers and data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    for i in range(5):  # Run 5 random tests
        random_sync_header = random.choice([0b01, 0b00, 0b11])
        random_data = random.getrandbits(64)

        dut.decoder_data_in.value = (random_sync_header << 64) | random_data
        dut.decoder_data_valid_in.value = 1

        expected_data = random_data if random_sync_header == 0b01 else 0x0000000000000000
        expected_sync_error = 0 if random_sync_header == 0b01 else 1

        # Apply test and check output
        await Timer(5, units="ns")  # Wait before next random test
        await RisingEdge(dut.clk_in)
        dut.decoder_data_valid_in.value = 0
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error)

@cocotb.test()
async def random_valid_data_test(dut):
    """ Test decoding with random sync headers and data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    for i in range(5):  # Run 5 random tests
        random_sync_header = random.choice([0b01])
        random_data = random.getrandbits(64)

        dut.decoder_data_in.value = (random_sync_header << 64) | random_data
        dut.decoder_data_valid_in.value = 1

        expected_data = random_data if random_sync_header == 0b01 else 0x0000000000000000
        expected_sync_error = 0 if random_sync_header == 0b01 else 1

        # Apply test and check output
        await Timer(5, units="ns")  # Wait before next random test
        await RisingEdge(dut.clk_in)
        dut.decoder_data_valid_in.value = 0
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error)

@cocotb.test()
async def control_only_test(dut):
    """ Test decoding for control-only mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Control-only mode test cases
    test_cases = [
        (0b10, 0x1E, 0x3C78F1E3C78F1E, 0xFEFEFEFEFEFEFEFE, 0, 0),  # All control characters
        (0b10, 0x1E, 0x00000000000000, 0x0707070707070707, 0, 0),  # All control characters
        (0b00, 0x1E, 0x00000000000000, 0x0707070707070707, 1, 0),  # All control characters
        (0b10, 0x11, 0x3C78F1E3C78F1E, 0xFEFEFEFEFEFEFEFE, 0, 1),  # All control characters
    ]

    for sync_header, type_field, data_in, expected_data, expected_sync_error, expected_decoder_error_out in test_cases:
        dut.decoder_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.decoder_data_valid_in.value = 1

        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)
        dut.decoder_data_valid_in.value = 0
        dut._log.info(f"Control-Only Test:\n"
                      f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error,
                           expected_control_out=0xFF, expected_decoder_error_out=expected_decoder_error_out)

@cocotb.test()
async def mixed_mode_test(dut):
    """ Test decoding for mixed mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Mixed mode test cases
    test_cases = [
        # Format: (sync_header, type_field, data_in, expected_data, expected_control_out, expected_sync_error, expected_decoder_error_out)
        (0b10, 0x33, 0xDDCCBB00000000, 0xDDCCBBFB07070707, 0x1F, 0, 0),  # Mixed mode example
        (0b10, 0x78, 0x3456789ABCDEF0, 0x3456789ABCDEF0FB, 0x01, 0, 0),  # Mixed mode example
        (0b10, 0x87, 0x00000000000000, 0x07070707070707FD, 0xFE, 0, 0),  # Mixed mode example
        (0b10, 0x99, 0x000000000000AE, 0x070707070707FDAE, 0xFE, 0, 0),  # Mixed mode example
        (0b10, 0xAA, 0x0000000000A5A5, 0x0707070707FDA5A5, 0xFC, 0, 0),  # Mixed mode example
        (0b10, 0xB4, 0x00000000FEED55, 0x07070707FDFEED55, 0xF8, 0, 0),  # Mixed mode example
        (0b10, 0xCC, 0x00000099887766, 0x070707FD99887766, 0xF0, 0, 0),  # Mixed mode example
        (0b10, 0xD2, 0x00001234567890, 0x0707FD1234567890, 0xE0, 0, 0),  # Mixed mode example
        (0b10, 0xE1, 0x00FFEEDDCCBBAA, 0x07FDFFEEDDCCBBAA, 0xC0, 0, 0),  # Mixed mode example
        (0b10, 0xFF, 0x773388229911AA, 0xFD773388229911AA, 0x80, 0, 0),  # Mixed mode example
        (0b10, 0x55, 0x070707FF070707, 0x0707079C0707079C, 0x11, 0, 0),  # Mixed mode example
        (0b10, 0x66, 0x7777770FDEEDDE, 0x777777FBDEEDDE9C, 0x11, 0, 0),  # Mixed mode example
        (0b10, 0x4B, 0x0000000ABCDEFF, 0x0707070755E6F79C, 0xF1, 0, 0),  # Mixed mode example
        (0b10, 0x2D, 0xAAAAAAF0000000, 0xAAAAAA9C07070707, 0x1F, 0, 0),  # Mixed mode example
    ]

    for sync_header, type_field, data_in, expected_data, expected_control_out, expected_sync_error, expected_decoder_error_out in test_cases:
        # Set inputs
        dut.decoder_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.decoder_data_valid_in.value = 1

        # Wait for the output to stabilize
        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)

        # Check outputs
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error,
                           expected_control_out=expected_control_out, expected_decoder_error_out=expected_decoder_error_out)

        # Deassert valid signal
        dut.decoder_data_valid_in.value = 0
        await RisingEdge(dut.clk_in)


@cocotb.test()
async def control_mixed_mode_sync_error_test(dut):
    """ Test decoding for mixed mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Mixed mode test cases
    test_cases = [
        # Format: (sync_header, type_field, data_in, expected_data, expected_control_out, expected_sync_error, expected_decoder_error_out)
        (0b11, 0x33, 0xDDCCBB00000000, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
        (0b00, 0x78, 0x3456789ABCDEF0, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
        (0b11, 0x87, 0x00000000000000, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
        (0b00, 0x99, 0x000000000000AE, 0x0000000000000000, 0x00, 1, 0),  # Mixed mode example
    ]

    for sync_header, type_field, data_in, expected_data, expected_control_out, expected_sync_error, expected_decoder_error_out in test_cases:
        # Set inputs
        dut.decoder_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.decoder_data_valid_in.value = 1

        # Wait for the output to stabilize
        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)


        # Check outputs
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error,
                           expected_control_out=expected_control_out, expected_decoder_error_out=expected_decoder_error_out)

        # Deassert valid signal
        dut.decoder_data_valid_in.value = 0
        await RisingEdge(dut.clk_in)


@cocotb.test()
async def control_mixed_mode_decoder_error_test(dut):
    """ Test decoding for mixed mode """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Mixed mode test cases
    test_cases = [
        # Format: (sync_header, type_field, data_in, expected_data, expected_control_out, expected_sync_error, expected_decoder_error_out)
        (0b10, 0x13, 0xDDCCBB00000000, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x18, 0x3456789ABCDEF0, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x27, 0x00000000000000, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x79, 0x000000000000AE, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x0A, 0x0000000000A5A5, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0xD4, 0x00000000FEED55, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x0C, 0x00000099887766, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
        (0b10, 0x22, 0x00001234567890, 0x0000000000000000, 0x00, 0, 1),  # Mixed mode example
    ]

    for sync_header, type_field, data_in, expected_data, expected_control_out, expected_sync_error, expected_decoder_error_out in test_cases:
        # Set inputs
        dut.decoder_data_in.value = (sync_header << 64) | (type_field << 56) | data_in
        dut.decoder_data_valid_in.value = 1

        # Wait for the output to stabilize
        await Timer(5, units="ns")
        await RisingEdge(dut.clk_in)


        # Check outputs
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error,
                           expected_control_out=expected_control_out, expected_decoder_error_out=expected_decoder_error_out)

        # Deassert valid signal
        dut.decoder_data_valid_in.value = 0
        await RisingEdge(dut.clk_in)


