
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random


async def reset(dut):
    await FallingEdge(dut.clock)
    dut.reset.value = 1

    await FallingEdge(dut.clock)
    dut.reset.value = 0
    print("[DEBUG] Reset complete")


async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0
