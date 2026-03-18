
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def reset_dut(rst, duration_ns = 20):
    # Restart Interface
    rst.value = 0
    await Timer(duration_ns, units="ns")
    rst.value = 1
    await Timer(duration_ns, units="ns")
    rst.value = 0
    await Timer(duration_ns, units='ns')
    rst._log.debug("Reset complete")


async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0
