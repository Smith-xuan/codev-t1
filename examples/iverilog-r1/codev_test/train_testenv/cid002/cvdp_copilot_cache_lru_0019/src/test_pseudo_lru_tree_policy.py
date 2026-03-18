import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random
import math
import harness_library as hrs_lb


def get_mru_way(recency, index, nways):
    depth = 0
    step = 0
    while depth < int(math.ceil(math.log2(nways))):
        direction = int(recency[index].value[(1 << depth) - 1 + step])
        step = (step << 1) | direction
        depth += 1

    return step


def get_plru_way(recency, index, nways):
    depth = 0
    step = 0
    while depth < int(math.ceil(math.log2(nways))):
        direction = 0 if int(recency[index].value[(1 << depth) - 1 + step]) else 1
        step = (step << 1) | direction
        depth += 1

    return step


async def test_pseudo_lru_tree_initialization(dut):
    """Test if the recency trees are correctly initialized to 0 after reset."""
    cocotb.log.info("Starting test_pseudo_lru_tree_initialization...")

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)

    await hrs_lb.reset(dut)

    for index in [0, nindexes-1]:
        for way in range(nways):
            recency_tree_value = int(dut.recency[index].value)
            assert recency_tree_value == 0, f"Tree for index {index} not initialized to 0."

    for i in range(4):
        index = random.randint(0, nindexes-1)
        for way in range(nways):
            recency_tree_value = int(dut.recency[index].value)
            assert recency_tree_value == 0, f"Tree for index {index} not initialized to 0."

    cocotb.log.info("test_pseudo_lru_tree_initialization passed.")


async def test_pseudo_lru_tree_hit_check_mru(dut):
    """Test if the MRU value is correct after a hit."""
    cocotb.log.info("Starting test_pseudo_lru_tree_hit_increment...")

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset(dut)

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)

    for index in [0, nindexes-1]:
        for target_way in [0, nways-1]:
            cocotb.log.debug(f"Target index: {index}, Target way: {target_way}")
            await hrs_lb.access_hit(dut, index, target_way)
            assert get_mru_way(dut.recency, index, nways) == target_way, "the hit way was not properly set as the MRU"

        for i in range(nways):
            target_way = random.randint(1, nways - 2)
            cocotb.log.debug(f"Target index: {index}, Target way: {target_way}")
            await hrs_lb.access_hit(dut, index, target_way)
            assert get_mru_way(dut.recency, index, nways) == target_way, "the hit way was not properly set as the MRU"

    # Better to exercise (stress) the recency tree for the same index
    index = random.randint(0, nindexes - 1)
    for i in range(2 * nways):
        target_way = random.randint(0, nways - 1)

        cocotb.log.debug(f"Target index: {index}, Target way: {target_way}")
        await hrs_lb.access_hit(dut, index, target_way)
        assert get_mru_way(dut.recency, index, nways) == target_way, "the hit way was not properly set as the MRU"

    cocotb.log.info("test_pseudo_lru_tree_hit_increment passed.")


async def test_pseudo_lru_tree_miss_check_mru(dut):
    """Test if the MRU value is correct after a miss."""
    cocotb.log.info("Starting test_pseudo_lru_tree_miss_increment...")

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset(dut)

    nways = int(dut.NWAYS.value)
    nindexes = int(dut.NINDEXES.value)

    for index in [0, nindexes-1]:
        for target_way in [0, nways-1]:
            cocotb.log.debug(f"Target index: {index}, Target way: {target_way}")
            replace_way = await hrs_lb.access_miss(dut, index, target_way)
            assert get_mru_way(dut.recency, index, nways) == replace_way, "the replaced way was not properly set as the MRU"

        for i in range(nways):
            target_way = random.randint(1, nways - 2)
            cocotb.log.debug(f"Target index: {index}, Target way: {target_way}")
            replace_way = await hrs_lb.access_miss(dut, index, target_way)
            assert get_mru_way(dut.recency, index, nways) == replace_way, "the replaced way was not properly set as the MRU"

    # Better to exercise (stress) the recency tree for the same index
    index = random.randint(0, nindexes - 1)
    for i in range(2 * nways):
        target_way = random.randint(0, nways - 1)
        cocotb.log.debug(f"Target index: {index}, Target way: {target_way}")
        replace_way = await hrs_lb.access_miss(dut, index, target_way)
        assert get_mru_way(dut.recency, index, nways) == replace_way, "the replaced way was not properly set as the MRU"

    cocotb.log.info("test_pseudo_lru_tree_miss_increment passed.")


async def test_pseudo_lru_tree_replace_order_after_hit(dut):
    """Test the replacement order chosen correctly after a hit."""
    cocotb.log.info("Starting test_pseudo_lru_tree_replace_order_after_hit...")

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset(dut)

    nindexes = int(dut.NINDEXES.value)
    nways = int(dut.NWAYS.value)

    for index in [0, nindexes-1]:
        target_way = get_plru_way(dut.recency, index, nways)
        await hrs_lb.access_hit(dut, index, target_way)
        assert int(dut.way_replace.value) == int(nways / 2) - 1

    index = random.randint(1, nindexes - 2)
    target_way = get_plru_way(dut.recency, index, nways)
    await hrs_lb.access_hit(dut, index, target_way)
    assert int(dut.way_replace.value) == int(nways / 2) - 1

    cocotb.log.info("test_pseudo_lru_tree_replace_order_after_hit passed.")


async def test_pseudo_lru_tree_replace_order_after_miss(dut):
    """Test the replacement order chosen correctly after a miss."""
    cocotb.log.info("Starting test_pseudo_lru_tree_replace_order_after_miss...")

    await hrs_lb.dut_init(dut)
    await hrs_lb.reset(dut)

    nindexes = int(dut.NINDEXES.value)
    nways = int(dut.NWAYS.value)

    for index in [0, nindexes-1]:
        target_way = get_plru_way(dut.recency, index, nways)
        await hrs_lb.access_miss(dut, index, target_way)
        assert int(dut.way_replace.value) == int(nways / 2) - 1

    index = random.randint(1, nindexes - 2)
    target_way = get_plru_way(dut.recency, index, nways)
    await hrs_lb.access_miss(dut, index, target_way)
    assert int(dut.way_replace.value) == int(nways / 2) - 1

    cocotb.log.info("test_pseudo_lru_tree_replace_order_after_miss passed.")


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

    cocotb.log.info(f"NWAYS: {nways}  NINDEXES: {nindexes}")

    await test_pseudo_lru_tree_initialization(dut)
    cocotb.log.info("Test 1: Initialization passed.")

    await test_pseudo_lru_tree_hit_check_mru(dut)
    cocotb.log.info("Test 2: Check MRU after hit.")

    await test_pseudo_lru_tree_miss_check_mru(dut)
    cocotb.log.info("Test 3: Check MRU after miss.")

    await test_pseudo_lru_tree_replace_order_after_hit(dut)
    cocotb.log.info("Test 4: Replacement order after hit.")

    await test_pseudo_lru_tree_replace_order_after_miss(dut)
    cocotb.log.info("Test 5: Replacement order after miss.")

    cocotb.log.info("All tests passed.")
