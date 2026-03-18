import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random
import math
import harness_library as hrs_lb


# Helper function to extract the counter value from the frequency array
def get_counter_value(frequency, index, way, counter_width):
    start_bit = way * counter_width
    end_bit = start_bit + (counter_width - 1)
    value = int(frequency[index].value[end_bit:start_bit])
    return value


async def test_lfu_initialization(dut):
    """Test if counters are correctly initialized to 0 after reset."""
    cocotb.log.info("Starting test_lfu_initialization...")

    nways = int(dut.NWAYS.value)
    counter_width = int(dut.COUNTERW.value)
    nindexes = int(dut.NINDEXES.value)

    await hrs_lb.reset(dut)

    for i in range(4):
        index = random.randint(0, nindexes-1)
        for way in range(nways):
            counter_value = get_counter_value(dut.frequency, index, way, counter_width)
            assert counter_value == 0, f"Counter {way} at index {index} not initialized to 0."

    cocotb.log.info("test_lfu_initialization passed.")


async def test_lfu_hit_increment(dut):
    """Test if a hit increments the correct counter."""
    cocotb.log.info("Starting test_lfu_hit_increment...")

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset(dut)

    await FallingEdge(dut.clock)
    index = random.randint(0, int(dut.NINDEXES.value) - 1)
    target_way = random.randint(0, int(dut.NWAYS.value) - 1)
    counter_width = int(dut.COUNTERW.value)

    cocotb.log.debug(f"Target index: {index}, Target way: {target_way}")
    dut.way_select.value = target_way
    dut.index.value = index
    dut.access.value = 1
    dut.hit.value = 1

    await FallingEdge(dut.clock)
    dut.access.value = 0

    # Check the target way hit had its counter incremented
    counter_value = get_counter_value(dut.frequency, index, target_way, counter_width)
    assert counter_value == 1, f"Counter {target_way} at index {index} not incremented on hit."

    # Check the correct way is selected for replacement
    if target_way == 0:
        assert int(dut.way_replace.value) == 1, "the next initial choice after 0 for replacement"
    else:
        assert int(dut.way_replace.value) == 0, "still selecting the first choice for replacement"

    cocotb.log.info("test_lfu_hit_increment passed.")


async def test_lfu_max_frequency(dut):
    """Test behavior when counters reach MAX_FREQUENCY."""
    cocotb.log.info("Starting test_lfu_max_frequency...")

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset(dut)

    index = random.randint(0, int(dut.NINDEXES.value) - 1)
    target_way = random.randint(0, int(dut.NWAYS.value) - 1)
    max_frequency = int(dut.MAX_FREQUENCY.value)
    counter_width = int(dut.COUNTERW.value)

    await FallingEdge(dut.clock)
    dut.way_select.value = target_way
    dut.index.value = index
    dut.access.value = 1
    dut.hit.value = 1

    cocotb.log.debug(f"Target index: {index}, Target way: {target_way}, MAX_FREQUENCY: {max_frequency}")
    for i in range(max_frequency + 2):  # Increment beyond MAX_FREQUENCY
        await FallingEdge(dut.clock)

    counter_value = get_counter_value(dut.frequency, index, target_way, counter_width)
    assert counter_value == max_frequency, f"Counter for way #{target_way}={counter_value} " \
                                           + "exceeded MAX_FREQUENCY={max_frequency}."
    assert int(dut.way_replace.value) != target_way, "the last way set to max frequency is never selected " \
                                                     + "for replacement"

    cocotb.log.info("test_lfu_max_frequency passed.")


async def test_lfu_miss(dut):
    """Test counter behavior in a miss."""
    cocotb.log.info("Starting test_lfu_miss...")

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset(dut)

    index = random.randint(0, int(dut.NINDEXES.value) - 1)
    target_way = random.randint(0, int(dut.NWAYS.value) - 1)
    counter_width = int(dut.COUNTERW.value)

    await FallingEdge(dut.clock)
    dut.way_select.value = target_way
    dut.index.value = index
    dut.access.value = 1
    dut.hit.value = 0
    replace_way = int(dut.way_replace.value)

    cocotb.log.debug(f"Target index: {index}, Replace Way: {replace_way}")
    await FallingEdge(dut.clock)

    counter_value = get_counter_value(dut.frequency, index, replace_way, counter_width)
    assert counter_value == 1, f"The replaced way must have frequency set to 1."

    cocotb.log.info("test_lfu_miss passed.")


async def test_lfu_edge_case_all_counters_high(dut):
    """Test edge case where all counters are high and a hit occurs."""
    cocotb.log.info("Starting test_lfu_edge_case_all_counters_high...")

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)
    max_frequency = int(dut.MAX_FREQUENCY.value)
    counter_width = int(dut.COUNTERW.value)

    await hrs_lb.reset(dut)

    index = random.randint(0, nindexes - 1)
    cocotb.log.debug(f"Setting all counters to MAX_FREQUENCY at index {index}")

    # Set all counters to MAX_FREQUENCY
    dut.index.value = index
    dut.hit.value = 1
    dut.access.value = 1
    for way in range(nways):
        dut.way_select.value = way
        for i in range(max_frequency):
            await FallingEdge(dut.clock)
            # Perform a hit on a target way

    for way in range(nways):
        assert get_counter_value(dut.frequency, index, way, counter_width) == max_frequency, "All counters are " \
            + "supposed to be with MAX_FREQUENCY value"

    target_way = random.randint(0, nways - 1)
    cocotb.log.debug(f"Target way for hit: {target_way}")

    # Perform a hit on a target way
    dut.way_select.value = target_way
    dut.index.value = index
    dut.hit.value = 1
    dut.access.value = 1

    await FallingEdge(dut.clock)
    dut.access.value = 0

    lfu_way = 0
    lfu_way_counter = max_frequency
    # Check counters' values
    for way in range(nways):
        counter_value = get_counter_value(dut.frequency, index, way, counter_width)
        if counter_value < lfu_way_counter:
            lfu_way = way
            lfu_way_counter = counter_value

        if way == target_way:
            assert counter_value == max_frequency, f"Counter {way} at index {index} not set correctly."
        if way != target_way:
            assert counter_value == max_frequency - 1, f"Counter {way} at index {index} not decremented correctly."

    assert int(dut.way_replace.value) == lfu_way, "the way to be replaced is the first, in order, with the least " \
                                                  + "frequency"

    cocotb.log.info("test_lfu_edge_case_all_counters_high passed.")


async def test_lfu_replacement_order(dut):
    """Test the replacement order."""
    cocotb.log.info("Starting test_lfu_replacement_order...")

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)
    max_frequency = int(dut.MAX_FREQUENCY.value)

    await hrs_lb.reset(dut)

    index = random.randint(0, nindexes - 1)

    dut.index.value = index
    dut.hit.value = 1
    dut.access.value = 1

    for way in range(nways):
        dut.way_select.value = way
        await FallingEdge(dut.clock)
        if way < (nways - 1):
            assert int(dut.way_replace.value) == way + 1

    for i in range(max_frequency):
        for way in range(nways):
            dut.way_select.value = way
            await FallingEdge(dut.clock)
            if way < (nways - 1):
                assert int(dut.way_replace.value) == way + 1

    cocotb.log.info("test_lfu_replacement_order passed.")


async def test_miss_lfu_replacement_order(dut):
    """Test the replacement order with successive misses."""
    cocotb.log.info("Starting test_miss_lfu_replacement_order...")

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)
    max_frequency = int(dut.MAX_FREQUENCY.value)

    await hrs_lb.reset(dut)

    index = random.randint(0, nindexes - 1)

    dut.index.value = index
    dut.hit.value = 0
    dut.access.value = 1

    for way in range(nways):
        dut.way_select.value = way
        await FallingEdge(dut.clock)
        if way < (nways - 1):
            assert int(dut.way_replace.value) == way + 1

    for i in range(max_frequency):
        for way in range(nways):
            dut.way_select.value = way
            await FallingEdge(dut.clock)
            if way < (nways - 1):
                assert int(dut.way_replace.value) == 0, f"Way #{way} " \
                    + "counter={get_counter_value(dut.frequency, index, way, counterw)}"

    dut.hit.value = 1
    dut.way_select.value = 0
    await FallingEdge(dut.clock)

    assert int(dut.way_replace.value) == 1, "the frequency of way #0 was increased, because all ways have the same" \
        + "frequency, the next way to replace must be #1"

    cocotb.log.info("test_random_miss_lfu_replacement_order passed.")


@cocotb.test()
async def test_policy_working(dut):
    """Main test function to call all tests."""
    cocotb.log.setLevel("DEBUG")
    cocotb.log.info("Starting test_policy_working...")

    clock_period = 10  # ns
    await cocotb.start(Clock(dut.clock, clock_period, units="ns").start())
    await hrs_lb.dut_init(dut)

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)
    max_frequency = int(dut.MAX_FREQUENCY.value)
    counter_width = int(dut.COUNTERW.value)
    cocotb.log.info(f"NWAYS: {nways}  NINDEXES: {nindexes}  COUNTERW: {counter_width}  MAX_FREQUENCY: {max_frequency}")

    await test_lfu_initialization(dut)
    cocotb.log.info("Test 1: Initialization passed.")

    await test_lfu_hit_increment(dut)
    cocotb.log.info("Test 2: Hit Increment passed.")

    await test_lfu_max_frequency(dut)
    cocotb.log.info("Test 3: MAX_FREQUENCY passed.")

    await test_lfu_miss(dut)
    cocotb.log.info("Test 4: Counter value for miss passed.")

    await test_lfu_edge_case_all_counters_high(dut)
    cocotb.log.info("Test 5: Edge Case with High Counters passed.")

    await test_lfu_replacement_order(dut)
    cocotb.log.info("Test 6: Replacement order passed.")

    await test_miss_lfu_replacement_order(dut)
    cocotb.log.info("Test 7: Replacement order (miss) passed.")

    cocotb.log.info("All tests passed.")
