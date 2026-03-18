import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import math

###############################################################################
# Helper functions for Q9.9 fixed-point
###############################################################################

def int_to_q9_9(value: int) -> int:
    if value < 0:
        value = 0
    elif value > (1 << 18) - 1:
        value = (1 << 18) - 1
    return value & 0x3FFFF  # 18 bits

def float_to_q9_9(val: float) -> int:
    if val < 0:
        scaled = 0
    else:
        scaled = int(round(val * (2**9)))
    return int_to_q9_9(scaled)

def q9_9_to_float(qval: int) -> float:
    return qval / float(2**9)

###############################################################################
# Prescale logic (replicate the RTL's pre_scaler module)
###############################################################################
def prescale(a: int, c: int) -> (int, int):
    if (a & (1 << 17)) != 0:
        shift = 8
    elif (a & (1 << 16)) != 0:
        shift = 7
    elif (a & (1 << 15)) != 0:
        shift = 6
    elif (a & (1 << 14)) != 0:
        shift = 5
    elif (a & (1 << 13)) != 0:
        shift = 4
    elif (a & (1 << 12)) != 0:
        shift = 3
    elif (a & (1 << 11)) != 0:
        shift = 2
    elif (a & (1 << 10)) != 0:
        shift = 1
    else:
        shift = 0

    b = a >> shift
    d = c >> shift
    return (b & 0x3FFFF, d & 0x3FFFF)

###############################################################################
# Gold–Schmidt iteration in Q9.9 (unsigned)
###############################################################################
def gold_schmidt_div_10_iter(dividend_fixed: int, divisor_fixed: int) -> int:
    D, N = prescale(divisor_fixed, dividend_fixed)

    TWO = (2 << 9)  # Q9.9 representation of 2.0
    for _ in range(10):
        F = TWO - D
        D = (D * F) >> 9
        N = (N * F) >> 9
        D &= 0x3FFFF
        N &= 0x3FFFF

    return N

###############################################################################
# Reset routine
###############################################################################
async def reset_sequence(dut, cycles=5):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    for _ in range(cycles-1):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

###############################################################################
# The main test
###############################################################################
@cocotb.test()
async def test_gold_div_corner_and_random(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    dut.start.value     = 0
    dut.dividend.value  = 0
    dut.divisor.value   = 0
    dut.rst_n.value     = 1

    await reset_sequence(dut, cycles=5)

    corner_tests = [
        (10.0, 4.0), (1.0, 1.0), (10.0, 1.0),
        (1.0, 10.0), (15.0, 5.0), (2.0, 0.5),
        (2.0, 7.0), (0.0, 10.0), (100.0, 1.0),
        (100.0, 50.0), (0.5, 2.0), (0.99, 0.99),
        (256.0, 1.0), (512.0, 2.0),
    ]

    for (divd_f, divs_f) in corner_tests:
        await run_single_test(dut, divd_f, divs_f)

    random_tests = 100
    for _ in range(random_tests):
        divd_f = round(random.uniform(0, 1024), 2)
        divs_f = round(random.uniform(0.1, 1024), 2)
        await run_single_test(dut, divd_f, divs_f)

async def run_single_test(dut, dividend_float, divisor_float):
    dividend_fixed = float_to_q9_9(dividend_float)
    divisor_fixed  = float_to_q9_9(divisor_float)

    dut.dividend.value = dividend_fixed
    dut.divisor.value  = divisor_fixed
    dut.start.value    = 1

    await RisingEdge(dut.clk)
    dut.start.value = 0

    latency_counter = 0

    while True:
        await RisingEdge(dut.clk)
        latency_counter += 1
        if dut.valid.value == 1:
            break

    dv_out_fixed = dut.dv_out.value.integer
    dv_out_float = q9_9_to_float(dv_out_fixed)

    if divisor_float < 1e-15:
        cocotb.log.warning(f"DIV-BY-ZERO: divd={dividend_float}, divs={divisor_float} => DUT={dv_out_float}")
        return

    ref_fixed = gold_schmidt_div_10_iter(dividend_fixed, divisor_fixed)
    ref_float = q9_9_to_float(ref_fixed)

    cocotb.log.info(
        f"DIV TEST: divd={dividend_float:.4f}, divs={divisor_float:.4f}, DUT={dv_out_float:.6f}, REF={ref_float:.6f}, Latency={latency_counter} cycles"
    )

    assert dv_out_float == ref_float, (
        f"ERROR: Mismatch! DUT={dv_out_float:.6f}, REF={ref_float:.6f}, Latency={latency_counter} cycles"
    )
    assert latency_counter == 13, (
        f"ERROR: Latency Mismatch! Expected=13, Actual={latency_counter} cycles"
    )
