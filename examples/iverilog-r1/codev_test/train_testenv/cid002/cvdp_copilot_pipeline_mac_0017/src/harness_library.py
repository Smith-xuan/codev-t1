
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def reset_dut(reset, duration_ns = 10):
    # Restart Interface
    reset.value = 1
    await Timer(duration_ns, units="ns")
    reset.value = 0
    await Timer(duration_ns, units="ns")
    reset.value = 1
    await Timer(duration_ns, units='ns')
    reset._log.debug("Reset complete")


async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0
    
async def calculate_mac_output(multiplicand, multiplier, N, counter, accumulator,valid_in, clk):
    mac_valid = 0
    if valid_in == 1 : 
        multiplication =  multiplicand * multiplier
        await RisingEdge( clk)
        accumulator += multiplication
        await RisingEdge( clk)
    if counter == (N-1):
        mac_valid = 1
        accumulator_s0 = accumulator
    return accumulator, mac_valid

