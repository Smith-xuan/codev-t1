import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random


async def reset(dut):
    await FallingEdge(dut.clock)
    dut.reset.value = 1

    await FallingEdge(dut.clock)
    dut.reset.value = 0
    cocotb.log.debug("Reset complete")


async def access_hit(dut, index_a, way_select_a):
    await FallingEdge(dut.clock)
    dut.access.value = 1
    dut.hit.value = 1
    dut.index.value = index_a
    dut.way_select.value = way_select_a

    await FallingEdge(dut.clock)
    cocotb.log.debug(f"way_replace: {dut.way_replace.value}")
    dut.access.value = 0
    dut.hit.value = 0


async def access_miss(dut, index_a, way_select_a):
    await FallingEdge(dut.clock)
    dut.access.value = 1
    dut.hit.value = 0
    dut.index.value = index_a
    dut.way_select.value = way_select_a
    await Timer(1, units='ns')
    read_way_replace = int(dut.way_replace.value)

    await FallingEdge(dut.clock)
    cocotb.log.debug(f"way_replace: 0b{dut.way_replace.value.integer:04b}")
    dut.access.value = 0
    dut.hit.value = 0
    return read_way_replace


async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0
