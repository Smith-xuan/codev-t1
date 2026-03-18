
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_policy_working(dut):
    """Test basic functionality of MRU policy."""

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)

    time_unit = 'ns'
    clock_period = 10
    clock = Clock(dut.clock, clock_period, units=time_unit)

    # Start clock
    await cocotb.start(clock.start())

    # Initialize DUT
    await hrs_lb.dut_init(dut)

    # Apply reset
    await hrs_lb.reset(dut)

    assert dut.way_replace.value == (nways-1), "the (N-1)th way starts as the MRU"

    await hrs_lb.access_hit(dut, 0, 2)
    assert dut.way_replace.value == 2, "way 2 is the MRU now"
    await hrs_lb.access_hit(dut, 0, 0)
    assert dut.way_replace.value == 0, "way 0 is the MRU now"

    await hrs_lb.access_hit(dut, 0, 2)
    await hrs_lb.access_hit(dut, 0, nways-1)

    # If there are more ways than 4, make a hit in all ways higher than position 3, leaving the higher as the MRU.
    if nways > 4:
        for way in range(4, nways):
            await hrs_lb.access_hit(dut, 0, way)

    assert dut.way_replace.value.integer == (nways-1), "the last accessed way is the MRU"

    await hrs_lb.access_hit(dut, 0, 3)
    assert dut.way_replace.value == 3, "after the MRU is hit"

    await hrs_lb.access_hit(dut, 0, 3)
    assert dut.way_replace.value == 3, "on a new hit in the same position, nothing changes"

    await hrs_lb.access_miss(dut, 0, 2)
    # In a miss, the last way_replace value will be used for replacement.
    # The module updates the way_replace for the next replacement.
    assert dut.way_replace.value == 3, "on a miss, the replaced way is the MRU, also the next to be replaced"

    await hrs_lb.access_miss(dut, 0, 2)
    # In a miss, the next the way to be replaced is set regardless of the way_select input.
    assert dut.way_replace.value == 3, "there was a miss on way 2 again, the next way to be replaced is still the way 3"

    # Now using another index
    await hrs_lb.access_hit(dut, 1, 0)
    assert dut.way_replace.value == 0, "after a hit on way 0, it is now the MRU"
    await hrs_lb.access_miss(dut, 1, 0)
    assert dut.way_replace.value == 0, "the replaced way (0) will continue to be the MRU"

    # Now using maximum indexes and maximum number of ways
    await hrs_lb.access_miss(dut, nindexes-1, 0)
    assert int(dut.way_replace.value) == nways-1, f"after a miss, the next position is {nways-1}"
    for way in range(1, nways):
        await hrs_lb.access_miss(dut, nindexes - 1, 0)
        next_way = nways-1
        assert int(dut.way_replace.value) == next_way, f"last replaced way is still the MRU ({next_way})"

    # Performing a hit in all ways successively
    await hrs_lb.access_hit(dut, nindexes-1, 0)
    assert int(dut.way_replace.value) == 0, f"after a hit, the way 0 is set for replacement"
    for way in range(1, nways):
        await hrs_lb.access_hit(dut, nindexes - 1, way)
        assert int(dut.way_replace.value) == way, f"next in way to be replaced, in order, is {way}"

    await FallingEdge(dut.clock)
