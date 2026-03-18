import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import cocotb.result as result

# Clock generation coroutine
async def clock_gen(dut):
    while True:
        dut.clk.value = 0
        await Timer(5, units='ns')  # 100 MHz clock
        dut.clk.value = 1
        await Timer(5, units='ns')

# Helper function to apply reset
async def apply_reset(dut):
    """Apply a reset signal to the DUT."""
    dut.reset.value = 1
    await Timer(20, units="ns")
    dut.reset.value = 0
    await RisingEdge(dut.clk)

# Test Case 1: No requests, expect `grant1` and `grant2` to be 0
@cocotb.test()
async def test_no_requests(dut):
    """Test 1: No requests active - both grants should be 0"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    await apply_reset(dut)
    dut.req1.value = 0
    dut.req2.value = 0
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should be 0 when no requests are active"
    assert dut.grant2.value == 0, "grant2 should be 0 when no requests are active"

# Test Case 2: Only req1 is asserted
@cocotb.test()
async def test_only_req1(dut):
    """Test 2: Only req1 asserted - grant1 should be 1, grant2 should be 0"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    await apply_reset(dut)
    dut.req1.value = 1
    dut.req2.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 1, "grant1 should be 1 when only req1 is asserted"
    assert dut.grant2.value == 0, "grant2 should be 0 when only req1 is asserted"

# Test Case 3: Only req2 is asserted
@cocotb.test()
async def test_only_req2(dut):
    """Test 3: Only req2 asserted - grant2 should be 1, grant1 should be 0"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req1.value = 0
    dut.req2.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should be 0 when only req2 is asserted"
    assert dut.grant2.value == 1, "grant2 should be 1 when only req2 is asserted"

# Test Case 4: Both req1 and req2 asserted, grant2 has priority
@cocotb.test()
async def test_both_requests(dut):
    """Test 4: Both req1 and req2 asserted - grant2 should have priority"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req1.value = 1
    dut.req2.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should be 0 when both req1 and req2 are asserted"
    assert dut.grant2.value == 1, "grant2 should be 1 when both req1 and req2 are asserted"

# Test Case 5: Deassert req2, req1 remains asserted
@cocotb.test()
async def test_req2_deasserted(dut):
    """Test 5: req2 deasserted, req1 still active - grant1 should be 1"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req1.value = 1
    dut.req2.value = 1
    await RisingEdge(dut.clk)  # Both requests active
    dut.req2.value = 0  # Deassert req2
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 1, "grant1 should be 1 when req2 is deasserted and req1 is active"
    assert dut.grant2.value == 0, "grant2 should be 0 when req2 is deasserted"

# Test Case 6: Both requests deasserted, expect both grants to be 0
@cocotb.test()
async def test_both_requests_deasserted(dut):
    """Test 6: Both requests deasserted - both grants should be 0"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req1.value = 1
    dut.req2.value = 1
    await RisingEdge(dut.clk)  # Both requests active
    dut.req1.value = 0  # Deassert both
    dut.req2.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should be 0 when both requests are deasserted"
    assert dut.grant2.value == 0, "grant2 should be 0 when both requests are deasserted"

# Test Case 7: req1 active first, then req2, grant2 should take priority
@cocotb.test()
async def test_req1_then_req2(dut):
    """Test 7: req1 active first, then req2 - grant2 should take priority"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req1.value = 1
    await RisingEdge(dut.clk)  # req1 asserted
    dut.req2.value = 1  # req2 asserted afterward
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should be 0 when req2 asserts after req1"
    assert dut.grant2.value == 1, "grant2 should be 1 when req2 asserts after req1"

# Test Case 8: Reset during active requests, expect both grants to be 0 after reset
@cocotb.test()
async def test_reset_during_request(dut):
    """Test 8: Reset during active request - both grants should be 0 after reset"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req1.value = 1
    dut.req2.value = 1
    await RisingEdge(dut.clk)  # Both requests active
    dut.reset.value = 1  # Apply reset
    await RisingEdge(dut.clk)
    dut.reset.value = 0  # Release reset
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should be 0 after reset"
    assert dut.grant2.value == 0, "grant2 should be 0 after reset"

# Test Case 9: req2 asserted after reset, only grant2 should be 1
@cocotb.test()
async def test_req2_after_reset(dut):
    """Test 9: req2 asserted after reset - only grant2 should be 1"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req2.value = 1
    dut.req1.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should be 0 when only req2 is asserted after reset"
    assert dut.grant2.value == 1, "grant2 should be 1 when only req2 is asserted after reset"

# Test Case 10: req1 asserted after req2 is granted, grant2 should remain 1
@cocotb.test()
async def test_req1_after_req2_granted(dut):
    """Test 10: req1 asserted after req2 is granted - grant2 should remain 1"""
    cocotb.start_soon(clock_gen(dut))  # Start the clock
    #await apply_reset(dut)
    dut.req2.value = 1
    await RisingEdge(dut.clk)  # req2 granted
    dut.req1.value = 1  # Assert req1 after req2 is granted
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.grant1.value == 0, "grant1 should remain 0 when req1 asserts after req2 is granted"
    assert dut.grant2.value == 1, "grant2 should remain 1 when req1 asserts after req2 is granted"
