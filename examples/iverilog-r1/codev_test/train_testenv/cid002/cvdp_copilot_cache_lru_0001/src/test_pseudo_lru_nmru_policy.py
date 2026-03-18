
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_policy_working(dut):
    """Test basic functionality of pseudo LRU/NMRU policy."""

    nways = int(dut.NWAYS.value)

    time_unit = 'ns'
    clock_period = 10
    clock = Clock(dut.clock, clock_period, units=time_unit)

    # Start clock
    await cocotb.start(clock.start())

    # Initialize DUT
    await hrs_lb.dut_init(dut)

    # Apply reset
    await hrs_lb.reset(dut)

    assert dut.recency[0].value == 0, "all recency sets are expected to be reset to 0"

    await hrs_lb.access_hit(dut, 0, 2)
    assert dut.way_replace.value == 0, "the smallest available positions are suggested first"
    await hrs_lb.access_hit(dut, 0, 0)
    assert dut.way_replace.value == 1, "the smallest available positions are suggested first"

    await hrs_lb.access_hit(dut, 0, 2)
    await hrs_lb.access_hit(dut, 0, 1)

    # If there are more ways than 4, make a hit in all ways higher than position 3, leaving it as the LRU.
    if nways > 4:
        for way in range(4, nways):
            await hrs_lb.access_hit(dut, 0, way)

    assert dut.way_replace.value == 3, "the last position is the LRU (last available)"

    await hrs_lb.access_hit(dut, 0, 3)
    assert dut.way_replace.value == 0, "after the LRU is hit, switch to NMRU policy, smallest available first"

    await hrs_lb.access_hit(dut, 0, 3)
    assert dut.way_replace.value == 0, "on a new hit in the same position, nothing changes"

    await hrs_lb.access_miss(dut, 0, 2)
    # In a miss, the last way_replace value will be used for replacement.
    # The module updates the way_replace for the next replacement.
    assert dut.way_replace.value == 1, "there was a miss on way 2, the previous way_replace was used, the next way to be replaced now is 1"

    await hrs_lb.access_miss(dut, 0, 2)
    # In a miss, the next the way to be replaced is set regardless of the way_select input.
    assert dut.way_replace.value == 2, "there was a miss on way 2 again, the next way to be replaced now is 2"

    # Now using another index
    await hrs_lb.access_miss(dut, 1, 0)
    assert dut.way_replace.value == 1, "after reset, starts in 0, after a miss, the next position is 1"
    await hrs_lb.access_miss(dut, 1, 0)
    assert dut.way_replace.value == 2, "next in way to be replaced, in order, is 2"

    await FallingEdge(dut.clock)
