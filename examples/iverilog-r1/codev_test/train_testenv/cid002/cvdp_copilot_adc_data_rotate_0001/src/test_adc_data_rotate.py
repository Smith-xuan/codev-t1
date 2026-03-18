import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def reset_dut(dut):
    """Reset the DUT (Device Under Test)"""
    # Set all input signals to their default values
    dut.i_rst_n.value = 0
    dut.i_adc_data_in.value = 0
    dut.i_shift_count.value = 0
    dut.i_shift_direction.value = 0

    # Wait for a clock cycle before releasing the reset
    await FallingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)


@cocotb.test()
async def test_adc_data_rotate(dut):
    """
    Test the ADC data rotation functionality.
    """

    # Start the clock for the DUT with a period of 10ns
    cocotb.start_soon(Clock(dut.i_clk, 10, units='ns').start())

    # Reset the DUT to ensure it starts from a known state
    await reset_dut(dut)

    # Test 1: Basic left rotation
    dut.i_adc_data_in.value = 179  # Input data
    dut.i_shift_count.value = 3           # Shift by 3 bits
    dut.i_shift_direction.value = 0       # Shift direction: Left

    # Wait for one clock cycle to process the input
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    assert dut.o_processed_data.value == 157, f"Test 1 failed: expected 157, got {dut.o_processed_data.value}"
    assert dut.o_operation_status.value == 1, f"Reset test failed: o_operation_status not reset to 0"

    # Test 2: Basic right rotation
    dut.i_adc_data_in.value = 179  # Input data
    dut.i_shift_count.value = 3           # Shift by 3 bits
    dut.i_shift_direction.value = 1       # Shift direction: Right

    # Wait for one clock cycle to process the input
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)

    assert dut.o_processed_data.value == 118, f"Test 2 failed: expected 118, got {dut.o_processed_data.value}"
    assert dut.o_operation_status.value == 1, f"Reset test failed: o_operation_status not reset to 0"

    # Test 3: No rotation
    dut.i_adc_data_in.value = 255  # Input data (all ones)
    dut.i_shift_count.value = 0           # No shift
    dut.i_shift_direction.value = 0       # Shift direction: Left (irrelevant for 0 shift)

    # Wait for one clock cycle to process the input
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    # Verify the output for no rotation

    assert dut.o_processed_data.value == 255, f"Test 3 failed: expected 255, got {dut.o_processed_data.value}"
    assert dut.o_operation_status.value == 1, f"Reset test failed: o_operation_status not reset to 0"

    # Test 4: Rotation greater than data width
    dut.i_adc_data_in.value = 179  # Input data
    dut.i_shift_count.value = 12          # Shift by 12 (greater than 8)
    dut.i_shift_direction.value = 0       # Shift direction: Left

    # Wait for one clock cycle to process the input
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    
    assert dut.o_processed_data.value == 59, f"Test 4 failed: expected 59, got {dut.o_processed_data.value}"
    assert dut.o_operation_status.value == 1, f"Reset test failed: o_operation_status not reset to 0"

    # Test 5: Reset functionality
    await reset_dut(dut)
    # Verify that outputs are reset correctly
    assert dut.o_processed_data.value == 0, f"Reset test failed: o_processed_data not reset to 0"
    assert dut.o_operation_status.value == 0, f"Reset test failed: o_operation_status not reset to 0"

    # Final message indicating all tests passed
    dut._log.info("All tests passed!")
