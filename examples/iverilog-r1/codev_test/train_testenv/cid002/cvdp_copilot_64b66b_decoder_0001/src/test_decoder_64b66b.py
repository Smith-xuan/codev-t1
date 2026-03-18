import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

# Helper function to initialize DUT inputs
async def dut_initialization(dut):
    """ Initialize all inputs for DUT """
    dut.rst_in.value = 1
    dut.decoder_data_in.value = 0
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle
    await RisingEdge(dut.clk_in)  # Wait for one clock cycle

# Helper function to check the output with debug logging
async def check_output(dut, expected_data, expected_sync_error):
    """Check DUT output against expected values"""
    await RisingEdge(dut.clk_in)  # Wait for the output latency of 1 cycle
    actual_data_out = dut.decoder_data_out.value.integer
    actual_sync_error = dut.sync_error.value.integer

    # Log the actual and expected outputs
    dut._log.info(f"Checking output:\n"
                  f"  Actual decoder_data_out: {hex(actual_data_out)}\n"
                  f"  Expected decoder_data_out: {hex(expected_data)}\n"
                  f"  Actual sync_error: {actual_sync_error}\n"
                  f"  Expected sync_error: {expected_sync_error}\n")

    assert actual_data_out == expected_data, \
        f"Data mismatch: decoder_data_out={hex(actual_data_out)} (expected {hex(expected_data)})"
    assert actual_sync_error == expected_sync_error, \
        f"Sync error mismatch: sync_error={actual_sync_error} (expected {expected_sync_error})"

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
    #await Timer(20, units="ns")  # hold reset for 20ns
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Set test inputs
    dut.decoder_data_in.value = (0b01 << 64) | 0xA5A5A5A5A5A5A5A5


    await Timer(5, units="ns")
    # Apply test and check output
    await RisingEdge(dut.clk_in)
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
    dut.decoder_data_in.value = (0b10 << 64) | 0xFFFFFFFFFFFFFFFF

    await Timer(5, units="ns")
    # Apply test and check output
    await RisingEdge(dut.clk_in)
     # Log inputs
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

        await Timer(5, units="ns")
        # Apply test and check output
        await RisingEdge(dut.clk_in)
         # Log inputs
        dut._log.info(f"Invalid Sync Test:\n"
                      f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
        await check_output(dut, expected_data=0x0000000000000000, expected_sync_error=1)

@cocotb.test()
async def random_Any_sync_header_data_test(dut):
    """ Test decoding with random sync headers and data """
    clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Initialize DUT inputs
    await dut_initialization(dut)
    await RisingEdge(dut.clk_in)

    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    for i in range(5):  # Run 5 random tests
        random_sync_header = random.choice([0b01, 0b10, 0b00, 0b11])
        random_data = random.getrandbits(64)

        dut.decoder_data_in.value = (random_sync_header << 64) | random_data

        expected_data = random_data if random_sync_header == 0b01 else 0x0000000000000000
        expected_sync_error = 0 if random_sync_header == 0b01 else 1

        # Apply test and check output
        await Timer(5, units="ns")  # Wait before next random test
        await RisingEdge(dut.clk_in)
         # Log inputs
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error)


    dut._log.info("Randomized tests completed successfully")

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

        expected_data = random_data if random_sync_header == 0b01 else 0x0000000000000000
        expected_sync_error = 0 if random_sync_header == 0b01 else 1

        # Apply test and check output
        await Timer(5, units="ns")  # Wait before next random test
        await RisingEdge(dut.clk_in)
         # Log inputs
        dut._log.info(f"Random Test {i+1}:\n"
                      f"  decoder_data_in: {hex(dut.decoder_data_in.value.integer)}")
        await check_output(dut, expected_data=expected_data, expected_sync_error=expected_sync_error)


    dut._log.info("Randomized tests completed successfully")


