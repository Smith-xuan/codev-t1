import cocotb 
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

import harness_library as hrs_lb

@cocotb.test()
async def test_Word_Change_Pulse(dut):
    DATA_WIDTH = int(dut.DATA_WIDTH.value)

    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    await hrs_lb.dut_init(dut)
    await RisingEdge(dut.clk)
    # Reset the DUT rst_n signal
    await hrs_lb.reset_dut(dut.reset, duration_ns=25, active=False)
    await RisingEdge(dut.clk)
    # Reset all inputs
    dut.data_in.value = 0
    dut.mask.value = (1 << DATA_WIDTH) - 1
    dut.match_pattern.value = 0
    dut.enable.value = 1
    dut.latch_pattern.value = 0

    for _ in range(2):
        await RisingEdge(dut.clk)    

    # Generate an initial rising edge for synchronization
    await RisingEdge(dut.clk)

    # Ensure word_change_pulse starts low
    assert dut.word_change_pulse.value == 0, "Initial word_change_pulse is not 0"

    # Run tests
    await random_changes_test(dut, DATA_WIDTH, num_tests=10)
    await RisingEdge(dut.clk)
    await test_no_change(dut, DATA_WIDTH)
    await RisingEdge(dut.clk)
    await test_single_bit_change(dut, DATA_WIDTH)
    await RisingEdge(dut.clk)
    await test_multiple_bits_change(dut, DATA_WIDTH)
    await RisingEdge(dut.clk)
    await test_back_to_back_changes(dut, DATA_WIDTH)
    await RisingEdge(dut.clk)
    await test_enable_functionality(dut, DATA_WIDTH)
    await RisingEdge(dut.clk)


    # Log success
    dut._log.info("All tests passed!")


async def test_enable_functionality(dut, data_width):
    """Test enable signal functionality."""
     # Reset the DUT
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0  
    dut.enable.value = 0

    for _ in range(5):
        random_data = random.randint(0, (1 << data_width) - 1)
        dut.data_in.value = random_data
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        assert dut.word_change_pulse.value == 0, (
            "word_change_pulse should remain low when enable is deasserted."
        )
        assert dut.pattern_match_pulse.value == 0, (
            "pattern_match_pulse should remain low when enable is deasserted."
        )


async def random_changes_test(dut, data_width, num_tests=10):
    prev_data = 0
    for _ in range(num_tests):
        random_data = random.randint(0, (1 << data_width) - 1)
        dut.data_in.value = random_data
        await RisingEdge(dut.clk)  

        expected_pulse = 1 if random_data != prev_data else 0
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        assert dut.word_change_pulse.value == expected_pulse, (
            f"word_change_pulse incorrect for data_in change from {prev_data:#0{data_width+2}b} "
            f"to {random_data:#0{data_width+2}b}, expected {expected_pulse}."
        )

        prev_data = random_data
        await RisingEdge(dut.clk)


async def test_no_change(dut, data_width):
    random_value = random.randint(0, (1 << data_width) - 1)
    dut.data_in.value = random_value
    for _ in range(2):
        await RisingEdge(dut.clk)  

    for _ in range(5):
        dut.data_in.value = random_value
        await RisingEdge(dut.clk)  
        await FallingEdge(dut.clk)
        assert dut.word_change_pulse.value == 0, (
            "word_change_pulse should remain low when data_in does not change"
        )


async def test_single_bit_change(dut, data_width):
    initial_value = random.randint(0, (1 << data_width) - 1)
    dut.data_in.value = initial_value
    await RisingEdge(dut.clk)

    for i in range(data_width):
        new_value = initial_value ^ (1 << i)
        dut.data_in.value = new_value
        expected_pulse = 1 if initial_value != new_value else 0
        await RisingEdge(dut.clk)  
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        assert dut.word_change_pulse.value == expected_pulse, (
            f"word_change_pulse should be {expected_pulse} when bit {i} changes from {initial_value:#0{data_width+2}b} "
            f"to {new_value:#0{data_width+2}b}."
        )
        initial_value = new_value
        await RisingEdge(dut.clk)


async def test_multiple_bits_change(dut, data_width):
    initial_value = random.randint(0, (1 << data_width) - 1)
    dut.data_in.value = initial_value
    await RisingEdge(dut.clk)

    for _ in range(5):
        new_value = random.randint(0, (1 << data_width) - 1)
        dut.data_in.value = new_value
        bitwise_change_detected = initial_value != new_value
        expected_pulse = 1 if bitwise_change_detected else 0
        await RisingEdge(dut.clk)  
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        assert dut.word_change_pulse.value == expected_pulse, (
            f"word_change_pulse incorrect for data_in change from {initial_value:#0{data_width+2}b} "
            f"to {new_value:#0{data_width+2}b}, expected {expected_pulse}."
        )
        initial_value = new_value
        await RisingEdge(dut.clk) 


async def test_back_to_back_changes(dut, data_width):
    num_iterations = 10

    prev_value = random.randint(0, (1 << data_width) - 1)
    dut.data_in.value = prev_value
    await RisingEdge(dut.clk)

    for _ in range(num_iterations):
        while True:
            new_value = random.randint(0, (1 << data_width) - 1)
            if new_value != prev_value:
                break

        dut.data_in.value = new_value
        await RisingEdge(dut.clk)

        value1 = prev_value
        prev_value = new_value
        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)

        expected_pulse = 1 if value1 != prev_value else 0
        word_change_pulse_val = dut.word_change_pulse.value

        assert word_change_pulse_val == expected_pulse, (
            f"word_change_pulse incorrect for change from {value1:#0{data_width+2}b} "
            f"to {prev_value:#0{data_width+2}b}, expected {expected_pulse}."
        )

    dut._log.info("All assertions passed successfully for data width {data_width}.")
