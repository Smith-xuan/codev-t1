import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Coroutine to generate clock signal
async def clock_gen(signal, period=10):
    """ Generate clock pulses. """
    while True:
        signal.value = 0
        await Timer(period // 2, units="ns")
        signal.value = 1
        await Timer(period // 2, units="ns")

@cocotb.test()
async def test_huffman_encoder(dut):
    """ Comprehensive test including random data and boundary condition testing. """
    # Start the clock generator coroutine
    cocotb.start_soon(clock_gen(dut.clk))

    # Reset the DUT
    dut.reset.value = 1
    await Timer(25, units="ns")  # Sufficient time to ensure reset is applied
    dut.reset.value = 0

    # Check reset state
    assert dut.huffman_code_out.value == 0, "Huffman code out should reset to 0"
    assert dut.code_valid.value == 0, "Code valid should reset to 0"
    assert dut.error_flag.value == 0, "Error flag should reset to 0"

    # Wait for a few clock cycles after reset
    for _ in range(10):
        await RisingEdge(dut.clk)

    # Random Test
    for _ in range(100):  # Conduct 100 random tests
        dut.data_in.value = random.randint(0, 15)
        dut.data_priority.value = random.randint(0, 3)
        dut.update_enable.value = random.choice([True, False])
        dut.config_symbol.value = random.randint(0, 15)
        dut.config_code.value = random.randint(0, 127)
        dut.config_length.value = random.randint(1, 7)

        await RisingEdge(dut.clk)

        # Insert random wait times
        await Timer(random.randint(5, 20), units='ns')

        # Reset randomly
        if random.choice([False, True]):
            dut.reset.value = 1
            await Timer(10, units="ns")
            dut.reset.value = 0

        await RisingEdge(dut.clk)

    # Boundary Conditions Test
    # Test minimum and maximum values
    dut.data_in.value = 0
    dut.data_priority.value = 0
    dut.update_enable.value = 1
    dut.config_symbol.value = 0
    dut.config_code.value = 0
    dut.config_length.value = 0

    await RisingEdge(dut.clk)

    dut.data_in.value = 15
    dut.data_priority.value = 3
    dut.config_symbol.value = 15
    dut.config_code.value = 127
    dut.config_length.value = 7

    await RisingEdge(dut.clk)

    # Observe outputs and ensure they react as expected
    assert dut.error_flag.value == 0, "Unexpected error flag set"

    # Additional checks as needed
