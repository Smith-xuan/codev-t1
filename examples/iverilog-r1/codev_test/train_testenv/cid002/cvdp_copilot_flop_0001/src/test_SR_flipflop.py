import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def reset_dut(dut):
    """Reset the DUT"""
    dut.i_rst_b.value = 0  # Assert asynchronous reset (active-low)
    dut.i_S.value = 0
    dut.i_R.value = 0
    await FallingEdge(dut.i_clk)
    dut.i_rst_b.value = 1  # Deassert reset
    await RisingEdge(dut.i_clk)


@cocotb.test()
async def test_SR_flipflop(dut):  # dut will be the object for RTL top
    # Generate clock
    cocotb.start_soon(Clock(dut.i_clk, 10, units='ns').start())  # timeperiod= 10ns

    # Reset the DUT
    await reset_dut(dut)
    assert dut.o_Q.value == 0, f"After reset, o_Q should be 0 but got {dut.o_Q.value}"
    assert dut.o_Q_b.value == 1, f"After reset, o_Q_b should be 1 but got {dut.o_Q_b.value}"

    # Test Set condition
    await FallingEdge(dut.i_clk)
    dut.i_S.value = 1
    dut.i_R.value = 0
    await FallingEdge(dut.i_clk)
    assert dut.o_Q.value == 1, f"Set failed, o_Q should be 1 but got {dut.o_Q.value}"
    assert dut.o_Q_b.value == 0, f"Set failed, o_Q_b should be 0 but got {dut.o_Q_b.value}"

    # Test Reset condition
    await FallingEdge(dut.i_clk)
    dut.i_S.value = 0
    dut.i_R.value = 1
    await FallingEdge(dut.i_clk)
    assert dut.o_Q.value == 0, f"Reset failed, o_Q should be 0 but got {dut.o_Q.value}"
    assert dut.o_Q_b.value == 1, f"Reset failed, o_Q_b should be 1 but got {dut.o_Q_b.value}"

    # Test Hold condition (both i_S and i_R are 0)
    await FallingEdge(dut.i_clk)
    dut.i_S.value = 0
    dut.i_R.value = 0
    o_Q_prev = dut.o_Q.value
    o_Q_b_prev = dut.o_Q_b.value
    await FallingEdge(dut.i_clk)
    assert dut.o_Q.value == o_Q_prev, f"Hold failed, o_Q changed to {dut.o_Q.value}"
    assert dut.o_Q_b.value == o_Q_b_prev, f"Hold failed, o_Q_b changed to {dut.o_Q_b.value}"

    # Test invalid state (both i_S and i_R are 1)
    await FallingEdge(dut.i_clk)
    dut.i_S.value = 1
    dut.i_R.value = 1
    await FallingEdge(dut.i_clk)
    assert dut.o_Q.value == 0, f"Invalid state failed, o_Q should be 0 but got {dut.o_Q.value}"
    assert dut.o_Q_b.value == 0, f"Invalid state failed, o_Q_b should be 0 but got {dut.o_Q_b.value}"

    # Re-test asynchronous reset
    await FallingEdge(dut.i_clk)
    dut.i_rst_b.value = 0  # Assert asynchronous reset
    await Timer(5, units='ns')  # Allow time for asynchronous reset to propagate
    assert dut.o_Q.value == 0, f"Asynchronous reset failed, o_Q should be 0 but got {dut.o_Q.value}"
    assert dut.o_Q_b.value == 1, f"Asynchronous reset failed, o_Q_b should be 1 but got {dut.o_Q_b.value}"
    dut.i_rst_b.value = 1  # Deassert asynchronous reset
    await FallingEdge(dut.i_clk)

    # Final check after reset deassertion
    assert dut.o_Q.value == 0, f"Final state check failed, o_Q should be 0 but got {dut.o_Q.value}"
    assert dut.o_Q_b.value == 0, f"Final state check failed, o_Q_b should be 1 but got {dut.o_Q_b.value}"
