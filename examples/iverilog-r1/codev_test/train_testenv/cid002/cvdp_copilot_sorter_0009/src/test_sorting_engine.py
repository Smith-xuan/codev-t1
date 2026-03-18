###############################################################################
# test_sorting_engine.py
#
# Cocotb testbench for the Brick Sort (odd-even sort) RTL module.
# This version is compatible with older cocotb versions that do not have
# certain APIs (e.g. cocotb.result.TestSkip, sim_time_utils.get_sim_time).
###############################################################################
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb import sim_time_utils


###############################################################################
# Utility Functions
###############################################################################
def list_to_bus(values, width):
    """
    Pack a list of integers into a single integer bus.

    values: list of integers
    width: bit-width of each integer
    returns: integer with bits concatenated in [values[0], values[1], ...] order
    """
    total_value = 0
    for i, val in enumerate(values):
        total_value |= (val & ((1 << width) - 1)) << (i * width)
    return total_value

def bus_to_list(bus_value, width, n):
    """
    Unpack a single integer bus into a list of integers.

    bus_value: integer representing concatenated data
    width: bit-width of each element
    n: number of elements
    returns: list of integers extracted from bus_value
    """
    values = []
    mask = (1 << width) - 1
    for i in range(n):
        chunk = (bus_value >> (i * width)) & mask
        values.append(chunk)
    return values

async def apply_reset(dut, cycles=2):
    """
    Assert and deassert reset for a given number of clock cycles.
    """
    dut.rst.value = 1
    dut.start.value = 0
    dut.in_data.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


###############################################################################
# Tests
###############################################################################
@cocotb.test()
async def test_basic_sort(dut):
    """
    Test a simple random set of values and verify the DUT's sorting.
    Also measure latency (in cycles) between start and done.
    """
    # Parameters from DUT
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    # Generate clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Apply reset
    await apply_reset(dut)

    # Prepare random input data
    input_values = [random.randint(0, (1 << WIDTH) - 1) for _ in range(N)]
    dut.in_data.value = list_to_bus(input_values, WIDTH)

    # Assert start for one clock cycle
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Measure cycles until done
    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.done.value.integer == 1:
            break

    out_data = dut.out_data.value.integer
    output_values = bus_to_list(out_data, WIDTH, N)

    # Check correctness
    ref_sorted = sorted(input_values)
    assert output_values == ref_sorted, (
        f"ERROR: DUT output={output_values} expected={ref_sorted}"
    )
    # Latency check (same approach as above)
    overhead = 4
    expected_latency = (N * (N - 1)) // 2 + overhead
    assert cycle_count == expected_latency, (
        f"Actual Latency: {cycle_count} Expected latency {expected_latency} for N={N}"
    )

    dut._log.info(f"[BASIC SORT] Input        : {input_values}")
    dut._log.info(f"[BASIC SORT] DUT Output   : {output_values}")
    dut._log.info(f"[BASIC SORT] Reference    : {ref_sorted}")
    dut._log.info(f"[BASIC SORT] Latency(cycles) = {cycle_count}")


@cocotb.test()
async def test_already_sorted(dut):
    """
    Test the engine with an already sorted array (ascending).
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    #await apply_reset(dut)

    # Already sorted input (0,1,2,...,N-1)
    input_values = list(range(N))
    dut.in_data.value = list_to_bus(input_values, WIDTH)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    while True:
        await RisingEdge(dut.clk)
        if dut.done.value.integer == 1:
            break

    out_data = dut.out_data.value.integer
    output_values = bus_to_list(out_data, WIDTH, N)

    # Verify
    assert output_values == input_values, (
        f"Sorted test failed, got {output_values}, expected {input_values}"
    )


@cocotb.test()
async def test_reverse_sorted(dut):
    """
    Test with reverse-sorted data to see if it sorts properly.
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    #await apply_reset(dut)

    # Reverse sorted input (N-1,N-2,...,0)
    input_values = list(range(N - 1, -1, -1))
    dut.in_data.value = list_to_bus(input_values, WIDTH)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    while True:
        await RisingEdge(dut.clk)
        if dut.done.value.integer == 1:
            break

    out_data = dut.out_data.value.integer
    output_values = bus_to_list(out_data, WIDTH, N)
    ref_sorted = sorted(input_values)

    assert output_values == ref_sorted, (
        f"Reverse sorted test failed, got {output_values}, expected {ref_sorted}"
    )

@cocotb.test()
async def test_all_equal(dut):
    """
    Test the engine with all elements equal.
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    #await apply_reset(dut)

    # All equal
    val = random.randint(0, (1 << WIDTH) - 1)
    input_values = [val] * N
    dut.in_data.value = list_to_bus(input_values, WIDTH)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    while True:
        await RisingEdge(dut.clk)
        if dut.done.value.integer == 1:
            break

    out_data = dut.out_data.value.integer
    output_values = bus_to_list(out_data, WIDTH, N)

    assert output_values == input_values, (
        f"All equal test failed, got {output_values}, expected {input_values}"
    )

@cocotb.test()
async def test_random_cases(dut):
    """
    Perform multiple random test vectors to gain coverage.
    Measure and report latency for each.
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    NUM_RANDOM_TESTS = 5

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    for test_idx in range(NUM_RANDOM_TESTS):
        # Reset
        #await apply_reset(dut)

        # Generate random input
        input_values = [random.randint(0, (1 << WIDTH) - 1) for _ in range(N)]
        dut.in_data.value = list_to_bus(input_values, WIDTH)

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Count cycles until done
        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.done.value.integer == 1:
                break

        out_data = dut.out_data.value.integer
        output_values = bus_to_list(out_data, WIDTH, N)
        ref_sorted = sorted(input_values)

        assert output_values == ref_sorted, (
            f"[RANDOM {test_idx}] got {output_values}, expected {ref_sorted}"
        )
        
        # Latency check (same approach as above)
        overhead = 4
        expected_latency = (N * (N - 1)) // 2 + overhead
        assert cycle_count == expected_latency, (
            f"[RANDOM {test_idx}] Actual Latency: {cycle_count} Expected latency {expected_latency} for N={N}"
        )

        dut._log.info(f"[RANDOM {test_idx}] Input = {input_values}")
        dut._log.info(f"[RANDOM {test_idx}] Output = {output_values}")
        dut._log.info(f"[RANDOM {test_idx}] Latency (cycles) = {cycle_count}")
