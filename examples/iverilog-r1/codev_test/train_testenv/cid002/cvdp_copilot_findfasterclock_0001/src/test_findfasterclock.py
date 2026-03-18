import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.result import TestSuccess


async def check_result(dut, expected):
    """
    Equivalent to the Verilog 'check_result' task:
      - If valid=1, then compare A_faster_than_B to 'expected'
      - Otherwise fail with "Valid signal not asserted"
    """
    if int(dut.valid.value) == 1:
        if int(dut.A_faster_than_B.value) == expected:
            dut._log.info(f"PASS: Output A_faster_than_B={dut.A_faster_than_B.value}, "
                          f"Expected={expected}")
        else:
            raise AssertionError(f"FAIL: Output A_faster_than_B={dut.A_faster_than_B.value}, "
                              f"Expected={expected}")
    else:
        raise AssertionError(f"FAIL: Valid signal not asserted (expected={expected})")


async def run_clock_a(dut, period_ns):
    """
    Toggles clk_A forever, with the given total period in ns.
    Cancel this task to 'disable' the clock.
    """
    half = period_ns / 2
    while True:
        dut.clk_A.value = 0
        await Timer(half, units="ns")
        dut.clk_A.value = 1
        await Timer(half, units="ns")


async def run_clock_b(dut, period_ns):
    """
    Toggles clk_B forever, with the given total period in ns.
    Cancel this task to 'disable' the clock.
    """
    half = period_ns / 2
    while True:
        dut.clk_B.value = 0
        await Timer(half, units="ns")
        dut.clk_B.value = 1
        await Timer(half, units="ns")


async def enable_clk_A_default(dut, clock_tasks):
    """
    Re-enable the default 10 ns clock_A.
    Cancel any existing clk_A task first.
    """
    if clock_tasks["clkA"] is not None:
        clock_tasks["clkA"].cancel()
    clock_tasks["clkA"] = cocotb.start_soon(run_clock_a(dut, 10))


async def enable_clk_B_default(dut, clock_tasks):
    """
    Re-enable the default 16 ns clock_B.
    Cancel any existing clk_B task first.
    """
    if clock_tasks["clkB"] is not None:
        clock_tasks["clkB"].cancel()
    clock_tasks["clkB"] = cocotb.start_soon(run_clock_b(dut, 16))


async def disable_clk_A(clock_tasks):
    """Disable clock_A by canceling its task."""
    if clock_tasks["clkA"] is not None:
        clock_tasks["clkA"].cancel()
        clock_tasks["clkA"] = None


async def disable_clk_B(clock_tasks):
    """Disable clock_B by canceling its task."""
    if clock_tasks["clkB"] is not None:
        clock_tasks["clkB"].cancel()
        clock_tasks["clkB"] = None


@cocotb.test()
async def test_findfasterclock(dut):
    """
    Replicates the same sequence as the original SystemVerilog testbench:
      - 6 test cases
      - Timings (#20, #200, etc. in ns)
      - Clock frequency changes, disabling, and stuck-clocks
      - Checking pass/fail conditions identically
    """

    # We'll track the tasks for each clock so we can enable/disable them.
    clock_tasks = {"clkA": None, "clkB": None}

    # Initialize signals
    dut.clk_A.value = 0
    dut.clk_B.value = 0
    dut.rst_n.value = 0

    # Start default clocks: A=10 ns, B=16 ns
    clock_tasks["clkA"] = cocotb.start_soon(run_clock_a(dut, 10))
    clock_tasks["clkB"] = cocotb.start_soon(run_clock_b(dut, 16))

    # ================
    # Test Case 1
    # ================
    # rst_n low 20 ns, then high, wait 200 ns => check A_faster_than_B=1
    dut._log.info("Test Case 1: clk_A faster than clk_B")
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await Timer(200, units="ns")
    await check_result(dut, expected=1)

    # ================
    # Test Case 2
    # ================
    # Make B faster (8 ns) than A (10 ns).
    dut._log.info("Test Case 2: clk_B faster than clk_A")
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    # Disable default B clock
    await disable_clk_B(clock_tasks)
    # Start new B clock with 8 ns period
    clock_tasks["clkB"] = cocotb.start_soon(run_clock_b(dut, 8))
    await Timer(200, units="ns")
    await check_result(dut, expected=0)

    # ================
    # Test Case 3
    # ================
    # Make A & B same freq => expect 0
    dut._log.info("Test Case 3: clk_A and clk_B same frequency")
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    # Kill the 8 ns B, then start B=10 ns
    await disable_clk_B(clock_tasks)
    # Cancel leftover forever loop
    # Actually not needed in Python if we handle it carefully, but just in case:
    clock_tasks["clkB"] = cocotb.start_soon(run_clock_b(dut, 10))
    await Timer(200, units="ns")
    await check_result(dut, expected=0)

    # ================
    # Test Case 4
    # ================
    # Actually stuck A => should not assert valid
    dut._log.info("Test Case 4: clk_A stuck")
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    # Disable A
    await disable_clk_A(clock_tasks)
    # Ensure B toggles at 8 ns (or any freq)
    await disable_clk_B(clock_tasks)
    clock_tasks["clkB"] = cocotb.start_soon(run_clock_b(dut, 8))
    await Timer(200, units="ns")

    if int(dut.valid.value) == 1:
        raise AssertionError("FAIL: Module should not assert valid for stuck clk_A")
    else:
        dut._log.info("PASS: Module handled stuck clk_A correctly")

    # ================
    # Test Case 5
    # ================
    # Stuck B => Should NOT assert valid
    dut._log.info("Test Case 5: clk_B stuck")
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    # Re-enable A (10 ns) but keep B stuck
    await enable_clk_A_default(dut, clock_tasks)
    await disable_clk_B(clock_tasks)
    await Timer(200, units="ns")
    if int(dut.valid.value) == 1:
        raise AssertionError("FAIL: Module should not assert valid for stuck clk_B")
    else:
        dut._log.info("PASS: Module handled stuck clk_B correctly")

    # ================
    # Test Case 6
    # ================
    # Reset in the middle: design should clear internal state,
    # then measure again and eventually assert valid=1 if both clocks toggle.
    dut._log.info("Test Case 6: Reset in the middle")
    await enable_clk_B_default(dut, clock_tasks)  # B=16 ns
    await Timer(50, units="ns")  # let them run a bit
    dut._log.info("Assert reset")
    dut.rst_n.value = 0
    await Timer(30, units="ns")  # hold reset for 30 ns
    dut._log.info("Deassert reset")
    dut.rst_n.value = 1
    await Timer(200, units="ns")  # enough time to re-measure
    if int(dut.valid.value) == 1:
        dut._log.info("PASS: Reset in the middle was handled correctly")
    else:
        raise AssertionError("FAIL: Reset did not let us measure again properly")

    dut._log.info("All test cases completed")
    raise TestSuccess("All tests passed (or handled) as in the original testbench")
