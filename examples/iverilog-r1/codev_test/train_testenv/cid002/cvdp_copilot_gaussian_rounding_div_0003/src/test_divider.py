# Filename: test_divider.py
import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock
import random


@cocotb.test()
async def test_divider_basic(dut):
    """
    Test the divider in a basic scenario with a few directed test vectors.
    """

    # Create a 10ns period clock on 'clk'
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Assert reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.dividend.value = 0
    dut.divisor.value = 0
    WIDTH = int(dut.WIDTH.value)

    # Wait a few clock cycles with reset asserted
    for _ in range(3):
        await RisingEdge(dut.clk)

    # De-assert reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # 1) Test dividing zero by non-zero
    await run_division_test(dut, dividend=0, divisor=1)

    if (WIDTH>4):
    # 2) Test dividing a smaller number by a larger one => quotient=0
        await run_division_test(dut, dividend=25, divisor=5)
        
    if (WIDTH>5):
    # 3) Test same numbers => quotient=1, remainder=0
        await run_division_test(dut, dividend=50, divisor=50)

    if (WIDTH>14):
    # 4) Test dividing by 1 => quotient=dividend, remainder=0
        await run_division_test(dut, dividend=12345, divisor=1)

    if (WIDTH>4):
    # 5) Test dividing a random (but small) example
        await run_division_test(dut, dividend=31, divisor=5)

    # Wait a couple more cycles at the end
    for _ in range(2):
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_divider_corner_cases(dut):
    """
    Test corner cases: dividing by zero, maximum values, etc.
    """

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Assert reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.dividend.value = 0
    dut.divisor.value = 0
    WIDTH = int(dut.WIDTH.value)

    # Wait a few clock cycles with reset asserted
    for _ in range(3):
        await RisingEdge(dut.clk)

    # De-assert reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # 1) dividend = 0 (Corner Case!)
    if (WIDTH>6):
        await run_division_test(dut, dividend=0, divisor=100)

    # 2) Very large dividend, smaller divisor
    #    Dividend = 0xFFFFFFFF, Divisor = 1
    max_val_dividend = (1 << (WIDTH)) - 1
    max_val_divisor = (1 << (WIDTH-1)) - 1
    await run_division_test(dut, dividend=max_val_dividend, divisor=1)

    # 3) Very large divisor, smaller dividend
    await run_division_test(dut, dividend=1, divisor=max_val_divisor)

    # Wait a couple more cycles at the end
    for _ in range(2):
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_divider_randomized(dut):
    """
    Perform randomized testing of the divider.
    """

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Assert reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.dividend.value = 0
    dut.divisor.value = 0
    WIDTH = int(dut.WIDTH.value)

    for _ in range(5):
        await RisingEdge(dut.clk)

    # De-assert reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    max_val_dividend = (1 << (WIDTH)) - 1
    max_val_divisor = (1 << (WIDTH-1)) - 1

    # Run a set of random tests
    num_tests = 20
    for _ in range(num_tests):
        dividend = random.randint(0, max_val_dividend)
        divisor  = random.randint(1, max_val_divisor)
        await run_division_test(dut, dividend, divisor)


async def run_division_test(dut, dividend, divisor):
    """
    Helper function that:
      1) Sets input signals
      2) Waits for the division operation to complete
      3) Checks correctness vs. Python's integer division
    """

    # --- 1) Drive inputs ---
    dut.start.value = 1
    dut.dividend.value = dividend
    dut.divisor.value  = divisor
    WIDTH = int(dut.WIDTH.value)

    # Wait 1 clock edge with start=1 to latch inputs
    await RisingEdge(dut.clk)
    dut.start.value = 0  # De-assert start

    # --- 2) Wait for valid signal ---
    # We know from your RTL that it takes WIDTH cycles to complete plus 1 cycle for DONE.
    # But let's be more general and wait until valid is high.
    # In the worst case, if the design doesn't raise 'valid', we time out.
    cycles_waited = 0
    while (dut.valid.value == 0):
        await RisingEdge(dut.clk)
        cycles_waited += 1

    # --- 3) Capture the outputs and compare against Python result ---
    # If 'valid' never went high, we'll just do the check anyway.
    quotient_hw = dut.quotient.value.integer
    remainder_hw = dut.remainder.value.integer

    # Python reference
    # Corner case: if divisor == 0, skip or define a special reference
    if divisor == 0:
        # You may decide your design does something special.
        # We'll just log a warning and skip correctness check for now.
        dut._log.warning(f"Division by zero attempted: dividend={dividend}, divisor=0. HW quotient={quotient_hw}, remainder={remainder_hw}")
        return

    quotient_sw = dividend // divisor
    remainder_sw = dividend % divisor

    # Print debug messages
    dut._log.info(f"Dividing {dividend} by {divisor}")
    dut._log.info(f"Hardware:  quotient={quotient_hw}, remainder={remainder_hw}, valid={dut.valid.value}")
    dut._log.info(f"Software:  quotient={quotient_sw}, remainder={remainder_sw}")
    
    max_cycles_to_wait = WIDTH + 2  # Some margin

    # Check correctness
    assert quotient_hw == quotient_sw, f"ERROR: Quotient mismatch. HW={quotient_hw}, SW={quotient_sw}"
    assert remainder_hw == remainder_sw, f"ERROR: Remainder mismatch. HW={remainder_hw}, SW={remainder_sw}"
    assert cycles_waited == max_cycles_to_wait, f"ERROR: Latency mismatch. Expected={max_cycles_to_wait}, Actual={cycles_waited}"
    dut._log.info("PASS\n")
