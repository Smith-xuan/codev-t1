# ============================================================
# test_sorting_engine.py
#
# Cocotb testbench for the "sorting_engine" module.
# 
# This testbench demonstrates:
#   1. Randomized tests
#   2. Directed corner cases
#   3. Latency measurements (clock cycles from start to done)
#   4. Asserting that the latency == expected_latency (for a full selection sort)
# ============================================================

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import math


# ------------------------------------------------------------------------------
# Helper function: reset the DUT
# ------------------------------------------------------------------------------
async def reset_dut(dut, cycles=2):
    """Drive reset high for 'cycles' clock cycles, then deassert."""
    dut.rst.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)  # Wait one more cycle after deassert


# ------------------------------------------------------------------------------
# Helper function: pack a list of integers into a single bus of width N*WIDTH
# ------------------------------------------------------------------------------
def pack_data(data_list, width):
    """
    data_list: list of integers
    width:     number of bits per integer
    """
    packed = 0
    for i, val in enumerate(data_list):
        w = int(width)
        packed |= (val & ((1 << w) - 1)) << (i * w)
    return packed


# ------------------------------------------------------------------------------
# Helper function: unpack a single bus of width N*WIDTH into a list of integers
# ------------------------------------------------------------------------------
def unpack_data(packed, n, width):
    """
    packed: integer that holds N elements
    n:      number of elements
    width:  number of bits per element
    """
    data_list = []
    w = int(width)
    mask = (1 << w) - 1
    for i in range(n):
        val = (packed >> (i * w)) & mask
        data_list.append(val)
    return data_list


# ------------------------------------------------------------------------------
# Compute expected latency for the multi-cycle counting sort hardware
# ------------------------------------------------------------------------------
def expected_latency(n, data_list):
    """
    Returns the expected total cycle count from the cycle after 'start'
    goes low until 'done' is first high, for the counting-sort design.
    We need the maximum value from data_list.
    """
    if len(data_list) == 0:
        # Edge case: if N=0 (not typical)
        return 0

    max_val = max(data_list)  # find the maximum input
    # Counting-sort latency formula:
    #  1 + n+1 + n+1 + max+2 + n+1 + max+1 + n+1 + n+1 + 1
    return 4*(n+1) + max_val + 4



@cocotb.test()
async def test_sorting_engine_random(dut):
    """
    Test #1: Random data, checking correctness and latency
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)

    # Generate random data
    random_data = [random.randint(0, (1 << WIDTH) - 1) for _ in range(N)]
    dut.in_data.value = pack_data(random_data, WIDTH)

    # Start sorting
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Measure latency in clock cycles
    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.done.value == 1:
            break

    # Check sorting correctness
    out_list = unpack_data(dut.out_data.value.integer, N, WIDTH)
    sorted_ref = sorted(random_data)
    assert out_list == sorted_ref, (
        f"ERROR: Output not sorted.\n"
        f"Input   = {random_data}\n"
        f"Got     = {out_list}\n"
        f"Expected= {sorted_ref}"
    )
    
    # Check latency == expected
    exp = expected_latency(N,sorted_ref)
    
    print(f"Input   = {random_data}\n"
          f"Got     = {out_list}\n"
          f"Expected= {sorted_ref}\n"
          f"Sorted in {cycle_count}\n"
          f"expected in {exp}")
          
    assert cycle_count == exp, (
        f"Latency mismatch for random data:\n"
        f"Measured: {cycle_count}, Expected: {exp}"
    )

    print(f"[Random Data] PASS: Sorted in {cycle_count} cycles (expected {exp}).")


@cocotb.test()
async def test_sorting_engine_already_sorted(dut):
    """
    Test #2: Already-sorted data
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Already-sorted data
    if(WIDTH >= math.log(N,2)):
        #sorted_data = list(range(N))
        sorted_data = list(range(N))
    else:
        sorted_data = [random.randint(0, (1 << WIDTH) - 1) for _ in range(N)]
    dut.in_data.value = pack_data(sorted_data, WIDTH)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Measure latency
    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.done.value == 1:
            break

    out_list = unpack_data(dut.out_data.value.integer, N, WIDTH)
    assert out_list == sorted(sorted_data), (
        f"ERROR: Output not sorted.\n"
        f"Input   = {sorted_data}\n"
        f"Got = {out_list}\n"
        f"Expected = {sorted_data}"
    )

    # Check latency
    exp = expected_latency(N,sorted_data)
    
    print(f"Input   = {sorted_data}\n"
          f"Got     = {out_list}\n"
          f"Expected= {sorted_data}\n"
          f"Sorted in {cycle_count}\n"
          f"expected in {exp}")
          
    assert cycle_count == exp, (
        f"Latency mismatch for already-sorted data:\n"
        f"Measured: {cycle_count}, Expected: {exp}"
    )

    print(f"[Already Sorted] PASS: Sorted in {cycle_count} cycles (expected {exp}).")


@cocotb.test()
async def test_sorting_engine_reverse_sorted(dut):
    """
    Test #3: Reverse-sorted data (worst-case scenario)
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reverse-sorted data
    if(WIDTH >= math.log(N,2)):
        rev_data = list(range(N - 1, -1, -1))
    else:
        rev_data = [random.randint(0, (1 << WIDTH) - 1) for _ in range(N)]
    dut.in_data.value = pack_data(rev_data, WIDTH)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Measure latency
    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.done.value == 1:
            break

    out_list = unpack_data(dut.out_data.value.integer, N, WIDTH)
    assert out_list == sorted(rev_data), (
        f"ERROR: Output not sorted.\n"
        f"Input   = {rev_data}\n"
        f"Got = {out_list}\n"
        f"Expected = {sorted(rev_data)}"
    )

    # Check latency
    exp = expected_latency(N,rev_data)
    
    print(f"Input   = {rev_data}\n"
          f"Got     = {out_list}\n"
          f"Expected= {sorted(rev_data)}\n"
          f"Sorted in {cycle_count}\n"
          f"expected in {exp}")
    assert cycle_count == exp, (
        f"Latency mismatch for reverse-sorted data:\n"
        f"Measured: {cycle_count}, Expected: {exp}"
    )

    print(f"[Reverse Sorted] PASS: Sorted in {cycle_count} cycles (expected {exp}).")


@cocotb.test()
async def test_sorting_engine_all_equal(dut):
    """
    Test #4: All elements the same
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())


    # All elements equal
    val = random.randint(0, (1 << WIDTH) - 1)
    equal_data = [val for _ in range(N)]
    #equal_data = [0, 7, 14, 9, 6, 14, 15, 2]
    dut.in_data.value = pack_data(equal_data, WIDTH)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Measure latency
    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.done.value == 1:
            break

    out_list = unpack_data(dut.out_data.value.integer, N, WIDTH)
    assert out_list == sorted(equal_data), (
        f"ERROR: Output not all-equal.\n"
        f"Input   = {equal_data}\n"
        f"Got = {out_list}\n"
        f"Latency Actual = {cycle_count}\n"
        f"Latency Exp = {expected_latency(N,sorted(equal_data))}"
    )

    # Check latency
    exp = expected_latency(N,sorted(equal_data))
    
    print(f"Input   = {equal_data}\n"
          f"Got     = {out_list}\n"
          f"Expected= {sorted(equal_data)}\n"
          f"Sorted in {cycle_count}\n"
          f"expected in {exp}")
          
    assert cycle_count == exp, (
        f"Latency mismatch for all-equal data:\n"
        f"Measured: {cycle_count}, Expected: {exp}"
    )

    print(f"[All Equal] PASS: Output is unchanged, sorted in {cycle_count} cycles (expected {exp}).")
    print(f"input {equal_data}.")
    print(f"Actual output {out_list}.")
    print(f"Expected output {sorted(equal_data)}.")
    print(f"Latency Actual {cycle_count}.")
    print(f"Latency Exp {exp}.")


@cocotb.test()
async def test_sorting_engine_single_element(dut):
    """
    Test #5: Single-element array (if N=1)
    """
    N = int(dut.N.value)
    WIDTH = int(dut.WIDTH.value)

    # If the DUT is not configured for N=1, skip
    if N != 1:
        return

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Single data
    single_data = [random.randint(0, (1 << WIDTH) - 1)]
    dut.in_data.value = pack_data(single_data, WIDTH)

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Measure latency
    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.done.value == 1:
            break

    out_list = unpack_data(dut.out_data.value.integer, N, WIDTH)
    assert out_list == single_data, (
        f"ERROR: Single-element array was changed.\n"
        f"Input   = {single_data}\n"
        f"Got = {out_list}\n"
        f"Expected = {single_data}"
    )

    # Check latency
    exp = expected_latency(N,single_data)
    
    print(f"Input   = {single_data}\n"
          f"Got     = {out_list}\n"
          f"Expected= {single_data}\n"
          f"Sorted in {cycle_count}\n"
          f"expected in {exp}")
          
    assert cycle_count == exp, (
        f"Latency mismatch for single-element data:\n"
        f"Measured: {cycle_count}, Expected: {exp}"
    )

    print(f"[Single Element] PASS: No change, done in {cycle_count} cycles (expected {exp}).")
