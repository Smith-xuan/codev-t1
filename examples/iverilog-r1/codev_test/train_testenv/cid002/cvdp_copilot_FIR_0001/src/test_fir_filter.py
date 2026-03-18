import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Asynchronous Reset Test
@cocotb.test()
async def async_reset_test(dut):
    """Test the asynchronous reset functionality of the FIR filter."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Ensure output is initially zero after reset
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    assert dut.output_sample.value == 0, "Reset failed, output should be zero immediately after reset."

    # Apply a value, then reset
    dut.input_sample.value = 10
    await RisingEdge(dut.clk)
    dut.reset.value = 1
    await Timer(1, units="ns")
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    assert dut.output_sample.value == 0, "Reset failed, output is not zero after asynchronous reset."

# Random Test
@cocotb.test()
async def random_test(dut):
    """Apply random inputs to the FIR filter and check for stability."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    for _ in range(100):
        rand_val = random.randint(-32768, 32767)
        dut.input_sample.value = rand_val
        await RisingEdge(dut.clk)

# Boundary Condition Test
@cocotb.test()
async def boundary_condition_test(dut):
    """Test boundary conditions of the FIR filter to ensure it handles extreme values correctly."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    # Max positive input
    dut.input_sample.value = 32767
    await RisingEdge(dut.clk)
    # Max negative input
    dut.input_sample.value = -32768
    await RisingEdge(dut.clk)
