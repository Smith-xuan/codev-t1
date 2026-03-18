import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
import random
import harness_library as hrs_lb


@cocotb.test()
async def test_clock_jitter_detection(dut):
    """Testbench for clock jitter detection module."""

    # Get parameter value from the DUT
    JITTER_THRESHOLD = int(dut.JITTER_THRESHOLD.value.integer)
    print(f"JITTER_THRESHOLD = {JITTER_THRESHOLD}")

    # Start the clock with a random period
    clock_period_ns = random.randint(JITTER_THRESHOLD, 100)  # Clock period in nanoseconds
    clock_period_sys_ns = JITTER_THRESHOLD * clock_period_ns  # Adjusted system clock period
    cocotb.start_soon(Clock(dut.clk, clock_period_ns, units='ns').start())
    await FallingEdge(dut.clk)
    sys_clk_gen = cocotb.start_soon(Clock(dut.system_clk, clock_period_sys_ns, units='ns').start())

    print("[INFO] System clock generation started.")
    print("[INFO] Clocks started.")

    # Initialize DUT
    await hrs_lb.dut_init(dut)

    # Apply reset
    await hrs_lb.reset_dut(dut.rst, clock_period_ns)
    dut.system_clk.value = 0

    # Wait for a couple of clock cycles to stabilize after reset
    for _ in range(2):
        await RisingEdge(dut.clk)

    # Simulate jitter by varying the `system_clk` input
    MIN_CYCLES = 100
    MAX_CYCLES = 1000
    cycle_num = random.randint(MIN_CYCLES, MAX_CYCLES)
    start_jitter = random.randint(10, MIN_CYCLES - 2 * JITTER_THRESHOLD)
    jitter_cycles = random.randint(1, 5)
    counter = 0
    sys_clk_r1 = 0
    sys_clk_generated = 0
    expected_jitter_detected = 0
    expected_jitter_detected_r1 = 0

    print(f"Running for {cycle_num} cycles...")
    print(f"Test setup:")
    print(f"Jitter start  : {start_jitter}")
    print(f"Jitter cycles : {jitter_cycles}")

    for cycle in range(cycle_num):
        # Simulate the normal clock behavior
        sys_clk = dut.system_clk.value.integer
        counter += 1

        # Introduce jitter for certain cycles
        if start_jitter <= cycle <= start_jitter + jitter_cycles:
            sys_clk_generated = 1
            sys_clk_gen.kill()
        elif sys_clk_generated == 1:
            await FallingEdge(dut.clk)
            sys_clk_gen = cocotb.start_soon(Clock(dut.system_clk, clock_period_sys_ns, units='ns').start())
            sys_clk_generated = 0

        sys_clk_r2 = sys_clk_r1
        await RisingEdge(dut.clk)
        sys_clk_r1 = sys_clk
        expected_jitter_detected_r1 = expected_jitter_detected

        if expected_jitter_detected == 1:
            expected_jitter_detected = 0

        print(f"sys_clk: {sys_clk}, sys_clk_r2: {sys_clk_r2}")
        sys_clk_posedge = sys_clk & ~sys_clk_r2

        if sys_clk_posedge == 1:
            print(f"Posedge detected, counter: {counter}!")
            expected_jitter_detected = int(
                counter != JITTER_THRESHOLD and counter != 0 and cycle > JITTER_THRESHOLD
            )
            if expected_jitter_detected == 1:
                print(f"[INFO] Expected Jitter detected at cycle {cycle}!")
            counter = 0

        # Check if jitter is detected
        actual_jitter_detected = dut.jitter_detected.value.integer
        if actual_jitter_detected == 1:
            print(f"[INFO] Actual Jitter detected at cycle {cycle}!")

        print(
            f"actual_jitter_detected: {actual_jitter_detected}, "
            f"expected_jitter_detected_r1: {expected_jitter_detected_r1}"
        )
        assert actual_jitter_detected == expected_jitter_detected_r1, (
            f"actual_jitter_detected ({actual_jitter_detected}) != "
            f"expected_jitter_detected_r1 ({expected_jitter_detected_r1})"
        )

    print("[INFO] Test completed successfully.")
