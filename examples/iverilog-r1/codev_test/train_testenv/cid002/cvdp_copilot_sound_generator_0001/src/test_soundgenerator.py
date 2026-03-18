import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_soundgenerator(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 100, units='ns').start())
    
    await hrs_lb.dut_init(dut)

    await FallingEdge(dut.clk)
    dut.nrst.value = 1
    await FallingEdge(dut.clk)
    dut.nrst.value = 0
    await FallingEdge(dut.clk)
    dut.nrst.value = 1

    await RisingEdge(dut.clk)
    assert dut.soundwave_o.value == 0, f"[ERROR] soundwave_o: {dut.soundwave_o.value}"
    assert dut.busy.value == 0, f"[ERROR] busy: {dut.busy.value}"
    assert dut.done.value == 0, f"[ERROR] done: {dut.done.value}"
    print(f'reset successful = {dut.done.value}')
    freq_count = 4
    sound_duration = 10
    await FallingEdge(dut.clk)
    dut.start.value = 1
    dut.sond_dur_ms_i.value = sound_duration
    dut.half_period_us_i.value = freq_count

    await FallingEdge(dut.clk)
    dut.start.value = 0
    assert dut.busy.value == 1, f"[ERROR] busy: {dut.busy.value}"
    print(f'busy signal asserted successfully = {dut.busy.value}')

    
    micro_count = 0
    tick_count = 0
    while True:
        await RisingEdge(dut.TickMilli)
        tick_count += 1
        cocotb.log.info(f"'sound' occurred! Current count: {tick_count}")
        if (tick_count == sound_duration):
            await RisingEdge(dut.clk)
            await FallingEdge(dut.clk)
            print(f'sound is generated and done signal is generated done signal value  = {dut.done.value}')
            assert dut.done.value == 1, f"[ERROR] done: {dut.done.value}"
            break

    
