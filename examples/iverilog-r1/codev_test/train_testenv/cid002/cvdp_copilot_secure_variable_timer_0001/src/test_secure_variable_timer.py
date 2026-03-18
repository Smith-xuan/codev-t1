import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def reset_dut(dut):
    """Reset the DUT (Device Under Test)"""
    # Set all input signals to their default values
    dut.i_rst_n.value = 0
    dut.i_data_in.value = 0
    dut.i_ack.value = 0
    # Wait for a clock cycle before releasing the reset
    await FallingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

async def send_serial_data(dut, bitstream):
    """Send a bitstream serially to the i_data_in port"""
    for bit in bitstream:
        dut.i_data_in.value = int(bit)
        await FallingEdge(dut.i_clk)

@cocotb.test()
async def test_secure_variable_timer(dut):
    """Test the secure_variable_timer module"""

    # Start the clock for the DUT with a period of 10ns
    cocotb.start_soon(Clock(dut.i_clk, 10, units='ns').start())

    # Reset the DUT to ensure it starts from a known state
    await reset_dut(dut)
    await FallingEdge(dut.i_clk)
    # Scenario 1: Send the 1101 pattern followed by a delay value of 6 (0110)
    start_pattern = "1101"
    delay_value = "0110"  # Binary for delay = 6
    await send_serial_data(dut, start_pattern + delay_value)
    await FallingEdge(dut.i_clk)
    # Check if the module correctly enters the counting phase
    assert dut.o_processing.value == 1, f"Timer should be in processing state after start sequence and delay configuration. {dut.o_processing.value}"
    assert dut.o_time_left.value == 6, "o_time_left should reflect the configured delay value"

    # Wait for counting to complete (7 * 1000 cycles)
    for i in range(7000):
        await FallingEdge(dut.i_clk)

    # Verify completion
    assert dut.o_completed.value == 1, "Timer should assert o_completed at the end of the counting phase"
    assert dut.o_processing.value == 0, "o_processing should be deasserted after counting phase"

    # Scenario 2: Acknowledge and reset the timer
    dut.i_ack.value = 1
    await FallingEdge(dut.i_clk)
    dut.i_ack.value = 0

    # Verify that the DUT returns to idle state
    for i in range(10):  # Allow 10 cycles to stabilize
        await RisingEdge(dut.i_clk)
    assert dut.o_completed.value == 0, "Timer should deassert o_completed after acknowledgment"
    assert dut.o_processing.value == 0, "Timer should remain in idle state after acknowledgment"

    # Add additional test cases as needed
