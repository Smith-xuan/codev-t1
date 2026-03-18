import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Initialize the DUT clock
async def init_clock(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

@cocotb.test()
async def test_window_types_and_data(dut):
    """Test FIR filter functionality across different window types with step inputs."""
    await init_clock(dut)
    dut.reset.value = 1
    await Timer(20, units='ns')
    dut.reset.value = 0

    window_types = [0, 1, 2, 3]  # Rectangular, Hanning, Hamming, Blackman
    test_inputs = [1000, 2000, 3000, 4000]  # Example step inputs

    for window in window_types:
        dut.window_type.value = window
        for data_in in test_inputs:
            dut.data_in.value = data_in
            await RisingEdge(dut.clk)
            print(f"Window {window}, Input {data_in}, Output {dut.data_out.value}")

@cocotb.test()
async def async_reset_test(dut):
    """Test the FIR filter's response to an asynchronous reset."""
    await init_clock(dut)
    dut.reset.value = 0  # Start with reset de-asserted

    # Test reset at various times relative to the clock edge
    for offset in [1, 5, 9]:  # ns offsets to the clock edge
        dut.reset.value = 1
        await Timer(offset, units='ns')
        dut.reset.value = 0
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')  # Allow one clock cycle post reset
        assert dut.data_out.value == 0, f"Failure: data_out should be zero after reset at {offset}ns."

    print("Enhanced async reset test passed.")

@cocotb.test()
async def boundary_condition_test(dut):
    """Test the FIR filter's handling of boundary input values."""
    await init_clock(dut)
    dut.reset.value = 1
    await Timer(20, units='ns')
    dut.reset.value = 0

    max_val = 0x7FFF  # Max positive value for a 16-bit signed integer
    min_val = 0x8000  # Max negative value for a 16-bit signed integer

    dut.data_in.value = max_val
    await RisingEdge(dut.clk)
    print(f"Input {max_val}, Output {dut.data_out.value}")

    dut.data_in.value = min_val
    await RisingEdge(dut.clk)
    print(f"Input {min_val}, Output {dut.data_out.value}")

@cocotb.test()
async def random_input_test(dut):
    """Test with random inputs to evaluate filter stability and response."""
    await init_clock(dut)
    dut.reset.value = 1
    await Timer(20, units='ns')
    dut.reset.value = 0

    for _ in range(100):
        dut.data_in.value = random.randint(0, 0xFFFF)
        dut.window_type.value = random.randint(0, 3)
        await RisingEdge(dut.clk)
        print(f"Random Test Input {dut.data_in.value}, Window {dut.window_type.value}, Output {dut.data_out.value}")
