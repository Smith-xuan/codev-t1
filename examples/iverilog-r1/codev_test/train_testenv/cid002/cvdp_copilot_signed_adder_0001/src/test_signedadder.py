import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_signedadder(dut):
    """Test the signedadder module."""

    DATA_WIDTH = 8  # Parameter for bit-width

    # Generate a clock
    clock = Clock(dut.i_clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.i_rst_n.value = 0
    dut.i_enable.value = 0
    dut.i_clear.value = 0
    dut.i_start.value = 0
    dut.i_mode.value = 0
    dut.i_operand_a.value = 0
    dut.i_operand_b.value = 0
    await Timer(20, units="ns")
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)

    # Test 1: Addition without overflow
    dut.i_enable.value = 1
    dut.i_start.value = 1
    dut.i_operand_a.value = 50  # Operand A
    dut.i_operand_b.value = 25  # Operand B
    dut.i_mode.value = 0  # Addition mode
    await RisingEdge(dut.i_clk)

    dut.i_start.value = 0
    await RisingEdge(dut.o_ready)

    assert dut.o_resultant_sum.value == 75, f"Expected 75, got {dut.o_resultant_sum.value}"
    assert dut.o_overflow.value == 0, f"Overflow should be 0 for this addition"

    # Test 2: Subtraction with overflow
    dut.i_start.value = 1
    dut.i_operand_a.value = -128  # Minimum 8-bit signed value
    dut.i_operand_b.value = 1  # Operand B
    dut.i_mode.value = 1  # Subtraction mode
    await RisingEdge(dut.i_clk)

    dut.i_start.value = 0
    await RisingEdge(dut.o_ready)

    assert dut.o_resultant_sum.value == 127, f"Expected 127, got {dut.o_resultant_sum.value}"
    assert dut.o_overflow.value == 1, f"Overflow should be 1 for this subtraction"

    # Test 3: Clear behavior
    dut.i_clear.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_clear.value = 0
    await RisingEdge(dut.i_clk)

    assert dut.o_resultant_sum.value == 0, f"Expected result to be cleared to 0"
    assert dut.o_status.value == 0, f"Expected state to reset to IDLE"

    # Test 4: Disabled operation
    dut.i_enable.value = 0
    dut.i_start.value = 1
    dut.i_operand_a.value = 60
    dut.i_operand_b.value = 40
    await RisingEdge(dut.i_clk)

    assert dut.o_resultant_sum.value == 0, f"No operation should occur when i_enable is 0"
    assert dut.o_ready.value == 0, f"Output should not be ready when module is disabled"

    # Test 5: Maximum addition without overflow
    dut.i_enable.value = 1
    dut.i_start.value = 1
    dut.i_operand_a.value = 127  # Maximum 8-bit signed value
    dut.i_operand_b.value = -1  # Operand B
    dut.i_mode.value = 0  # Addition mode
    await RisingEdge(dut.i_clk)

    dut.i_start.value = 0
    await RisingEdge(dut.o_ready)

    assert dut.o_resultant_sum.value == 126, f"Expected 126, got {dut.o_resultant_sum.value}"
    assert dut.o_overflow.value == 0, f"Overflow should be 0 for this addition"

    # Test 6: Negative addition causing overflow
    dut.i_start.value = 1
    dut.i_operand_a.value = -128  # Minimum 8-bit signed value
    dut.i_operand_b.value = -1  # Operand B
    dut.i_mode.value = 0  # Addition mode
    await RisingEdge(dut.i_clk)

    dut.i_start.value = 0
    await RisingEdge(dut.o_ready)

    assert dut.o_overflow.value == 1, f"Overflow should be 1 for this addition"

    # Test 7: Reset functionality during operation
    dut.i_operand_a.value = 50
    dut.i_operand_b.value = 25
    dut.i_mode.value = 0
    dut.i_start.value = 1
    await RisingEdge(dut.i_clk)

    dut.i_rst_n.value = 0  # Trigger reset
    await RisingEdge(dut.i_clk)
    dut.i_rst_n.value = 1

    assert dut.o_resultant_sum.value == 0, f"Result should reset to 0 after reset"
    assert dut.o_status.value == 0, f"State should reset to IDLE after reset"
    assert dut.o_ready.value == 0, f"Ready should reset to 0 after reset"

    # Test 8: State machine flow
    dut.i_start.value = 1
    dut.i_enable.value = 1
    dut.i_operand_a.value = 20
    dut.i_operand_b.value = 10
    dut.i_mode.value = 0  # Addition mode
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    assert dut.o_status.value == 1, f"Expected state to be LOAD after i_start"
    await FallingEdge(dut.i_clk)

    assert dut.o_status.value == 2, f"Expected state to be COMPUTE during operation"
    await FallingEdge(dut.i_clk)

    assert dut.o_status.value == 3, f"Expected state to be OUTPUT when results are ready"
