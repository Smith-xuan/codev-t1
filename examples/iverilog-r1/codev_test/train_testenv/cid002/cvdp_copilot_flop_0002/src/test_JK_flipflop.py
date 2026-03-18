import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

async def reset_dut(dut):
    """Reset the DUT"""
    dut.i_rst_b.value = 0
    dut.i_J.value = 0
    dut.i_K.value = 0
    await FallingEdge(dut.i_clk)
    dut.i_rst_b.value = 1
    await RisingEdge(dut.i_clk)

@cocotb.test()
async def test_JK_flipflop(dut):
    """Comprehensive test for JK Flip-Flop without using vectors"""
    # Generate clock
    cocotb.start_soon(Clock(dut.i_clk, 10, units="ns").start())  # 10ns clock period

    # Reset the DUT
    await reset_dut(dut)
    assert dut.o_Q.value == 0, f"After reset, o_Q should be 0 but is {dut.o_Q.value}"
    assert dut.o_Q_b.value == 1, f"After reset, o_Q_b should be 1 but is {dut.o_Q_b.value}"

    # Test Memory State (J=0, K=0)
    dut.i_J.value = 0
    dut.i_K.value = 0
    await FallingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    expected_Q = dut.o_Q.value.integer  # Should retain the previous state
    assert dut.o_Q.value == expected_Q, f"Memory state failed: o_Q={dut.o_Q.value} expected {expected_Q}"
    assert dut.o_Q_b.value == ~expected_Q & 0x1, f"Memory state failed: o_Q_b={dut.o_Q_b.value} expected {~expected_Q & 0x1}"

    # Test Reset State (J=0, K=1)
    dut.i_J.value = 0
    dut.i_K.value = 1
    await FallingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    expected_Q = 0
    assert dut.o_Q.value == expected_Q, f"Reset state failed: o_Q={dut.o_Q.value} expected {expected_Q}"
    assert dut.o_Q_b.value == 1, f"Reset state failed: o_Q_b={dut.o_Q_b.value} expected 1"

    # Test Set State (J=1, K=0)
    dut.i_J.value = 1
    dut.i_K.value = 0
    await FallingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    expected_Q = 1
    assert dut.o_Q.value == expected_Q, f"Set state failed: o_Q={dut.o_Q.value} expected {expected_Q}"
    assert dut.o_Q_b.value == 0, f"Set state failed: o_Q_b={dut.o_Q_b.value} expected 0"

    # Test Toggle State (J=1, K=1)
    # First Toggle
    dut.i_J.value = 1
    dut.i_K.value = 1
    expected_Q = not dut.o_Q.value.integer
    await FallingEdge(dut.i_clk)
    # await FallingEdge(dut.i_clk)
    assert dut.o_Q.value == expected_Q, f"Toggle state failed: o_Q={dut.o_Q.value} expected {expected_Q}"
    assert dut.o_Q_b.value == ~expected_Q & 0x1, f"Toggle state failed: o_Q_b={dut.o_Q_b.value} expected {~expected_Q & 0x1}"

    # Second Toggle (back to original state)
    dut.i_J.value = 1
    dut.i_K.value = 1
    expected_Q = not dut.o_Q.value.integer
    await FallingEdge(dut.i_clk)
    # await FallingEdge(dut.i_clk)
    assert dut.o_Q.value == expected_Q, f"Toggle back failed: o_Q={dut.o_Q.value} expected {expected_Q}"
    assert dut.o_Q_b.value == ~expected_Q & 0x1, f"Toggle back failed: o_Q_b={dut.o_Q_b.value} expected {~expected_Q & 0x1}"

    # Test Asynchronous Reset
    dut.i_rst_b.value = 0  # Assert reset asynchronously
    dut.i_J.value = 0
    dut.i_K.value = 0
    await Timer(5, units="ns")  # Wait for reset to take effect
    assert dut.o_Q.value == 0, f"During reset, o_Q should be 0 but is {dut.o_Q.value}"
    assert dut.o_Q_b.value == 1, f"During reset, o_Q_b should be 1 but is {dut.o_Q_b.value}"

    dut.i_rst_b.value = 1  # Deassert reset
    await FallingEdge(dut.i_clk)
    assert dut.o_Q.value == 0, f"After deasserting reset, o_Q should remain 0 but is {dut.o_Q.value}"
    assert dut.o_Q_b.value == 1, f"After deasserting reset, o_Q_b should remain 1 but is {dut.o_Q_b.value}"

    # Validate State Retention (Hold State)
    dut.i_J.value = 0
    dut.i_K.value = 0
    await FallingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    expected_Q = dut.o_Q.value.integer  # Should hold the previous state
    assert dut.o_Q.value == expected_Q, f"Hold state failed: o_Q={dut.o_Q.value} expected {expected_Q}"
    assert dut.o_Q_b.value == ~expected_Q & 0x1, f"Hold state failed: o_Q_b={dut.o_Q_b.value} expected {~expected_Q & 0x1}"

    cocotb.log.info("All tests passed without using vectors!")
