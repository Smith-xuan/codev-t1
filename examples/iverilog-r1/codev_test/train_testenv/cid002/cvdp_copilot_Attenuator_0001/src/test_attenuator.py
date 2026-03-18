import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, Edge
from cocotb import sim_time_utils
import random

################################################################################
# Helper: drive data, then wait 1 extra clk_div2 cycle to let the FSM sync
################################################################################
async def drive_data(dut, new_data, desc=""):
    dut.data.value = new_data
    cocotb.log.info(f"[drive_data] {desc} => setting data={new_data:05b}")
    # Wait 1 or 2 cycles of clk_div2 so the FSM can do IDLE->LOAD->SHIFT
    # We'll do 1 full cycle of 'clk_div2' by waiting on a rising edge
    #   of dut.clk_div2 (or ~some ns delay).
    await RisingEdge(dut.clk_div2)

################################################################################
# SHIFT Check: read bits from ATTN_DATA each time ATTN_CLK rises
################################################################################
async def check_shift_cycles(dut, expected_bits):
    # We expect 'len(expected_bits)' SHIFT pulses
    for i, exp_bit in enumerate(expected_bits, start=1):
        await RisingEdge(dut.ATTN_CLK)
        got_bit = int(dut.ATTN_DATA.value)
        if got_bit == exp_bit:
            cocotb.log.info(f" SHIFT cycle={i}, data_ok={got_bit} (expected={exp_bit})")
        else:
            cocotb.log.error(f" SHIFT cycle={i}, EXPECTED={exp_bit}, GOT={got_bit}")
    # Next, await latch pulse
    await RisingEdge(dut.ATTN_LE)
    cocotb.log.info(" LATCH pulse observed! Data latched.")


@cocotb.test()
async def test_reset_behavior(dut):
    """
    Testcase #1:
      - Assert/deassert reset,
      - Check outputs are zero,
      - No SHIFT if data doesn't change.
    """
    cocotb.start_soon(Clock(dut.clk, 40, units='ns').start())

    # Reset
    dut.reset.value = 1
    dut.data.value  = 0
    cocotb.log.info("[test_reset_behavior] Reset asserted at time 0.")

    await Timer(200, units='ns')
    dut.reset.value = 0
    cocotb.log.info(f"[test_reset_behavior] Reset deasserted at {sim_time_utils.get_sim_time('ns')} ns.")

    # Wait a bit
    await Timer(100, units='ns')

    # Check outputs
    if dut.ATTN_CLK.value != 0:
        cocotb.log.error("ATTN_CLK not zero after reset!")
    if dut.ATTN_DATA.value != 0:
        cocotb.log.error("ATTN_DATA not zero after reset!")
    if dut.ATTN_LE.value != 0:
        cocotb.log.error("ATTN_LE not zero after reset!")

    cocotb.log.info("[test_reset_behavior] Done.")


@cocotb.test()
async def test_scenario_detailed(dut):
    """
    Testcase #2:
      - Known scenario changes: data=10101,11111,01010
      - SHIFT + LATCH each time
      - We wait a short cycle after each drive to sync the FSM
    """
    cocotb.start_soon(Clock(dut.clk, 40, units='ns').start())

    # Reset
    dut.reset.value = 1
    dut.data.value  = 0
    cocotb.log.info("[test_scenario_detailed] Reset asserted.")
    await Timer(200, units='ns')
    dut.reset.value = 0
    cocotb.log.info("[test_scenario_detailed] Reset deasserted.")
    await Timer(300, units='ns')

    # Scenario B: data=10101 => SHIFT out bits [1,0,1,0,1]
    await drive_data(dut, 0b10101, desc="SCENARIO B: 10101")
    expected_bits_B = [1,0,1,0,1]
    await check_shift_cycles(dut, expected_bits_B)
    await Timer(300, units='ns')

    # Scenario C: data=11111 => SHIFT out bits [1,1,1,1,1]
    await drive_data(dut, 0b11111, desc="SCENARIO C: 11111")
    expected_bits_C = [1,1,1,1,1]
    await check_shift_cycles(dut, expected_bits_C)
    await Timer(300, units='ns')

    # Scenario D: data=01010 => SHIFT out bits [0,1,0,1,0]
    await drive_data(dut, 0b01010, desc="SCENARIO D: 01010")
    expected_bits_D = [0,1,0,1,0]
    await check_shift_cycles(dut, expected_bits_D)
    await Timer(300, units='ns')

    cocotb.log.info("[test_scenario_detailed] All scenario checks done.")


@cocotb.test()
async def test_random_data(dut):
    cocotb.start_soon(Clock(dut.clk, 40, units='ns').start())

    dut.reset.value = 1
    dut.data.value  = 0
    cocotb.log.info("[test_random_data] Reset asserted.")
    await Timer(200, units='ns')
    dut.reset.value = 0
    cocotb.log.info("[test_random_data] Reset deasserted.")
    await Timer(300, units='ns')

    prev_val = -1
    for i in range(5):
        rnd_val = random.randint(1, 31)
        while rnd_val == prev_val:
            rnd_val = random.randint(1, 31)

        cocotb.log.info(f"[test_random_data] Iteration={i+1}, data={rnd_val:05b}")
        await drive_data(dut, rnd_val, desc=f"Random{i+1}")

        expected_bits = [(rnd_val >> (4 - j)) & 1 for j in range(5)]
        await check_shift_cycles(dut, expected_bits)

        await Timer(random.randint(200, 1000), units='ns')
        prev_val = rnd_val

    cocotb.log.info("[test_random_data] Done with random test!")
