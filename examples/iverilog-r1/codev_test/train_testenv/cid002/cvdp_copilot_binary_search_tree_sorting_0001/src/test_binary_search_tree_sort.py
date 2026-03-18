import cocotb
from cocotb.triggers import RisingEdge, Timer
import random

def create_balanced_array(sorted_array):
    # Recursive function to create a balanced array
    if not sorted_array:
        return []
    mid = len(sorted_array) // 2
    return [sorted_array[mid]] + create_balanced_array(sorted_array[:mid]) + create_balanced_array(sorted_array[mid + 1:])

def calculate_latency(array_size, sorted):
    if array_size == 1: 
        # (INIT + INSERT = 2) + (INIT + Complete (for any node)) + IDLE 
        latency_build_tree = 5
        # (INIT + update stack + process + check for right + in left node + process(finish) + 1(done set))
        latency_sort_tree = 7
    
    if sorted:

        latency_start = 1
        # For any node (INIT + INSERT = 2) = 2 * array_size + 2 (INIT + Complete (final))
        # for sorted(for each node traverse until current depth) = (sum of array_size-1) = (array_size -1) * array_size / 2
        latency_build_tree = ((array_size - 1) * array_size)/2 + 2 * array_size + 2

        # (Every node goes thorugh traverse left + process node + assign right + check left) + last node + init + leftmost node iwth no left child
        latency_sort_tree = 4 * array_size + 3

    total_latency = latency_start + latency_build_tree + latency_sort_tree

    return total_latency


@cocotb.test()
async def test_bst_sorter(dut):
    ARRAY_SIZE = int(dut.ARRAY_SIZE.value)
    DATA_WIDTH = int(dut.DATA_WIDTH.value)

    clk_period = 10  # ns
    random.seed(0)  # For reproducibility

    cocotb.start_soon(clock(dut, clk_period))

    await reset_dut(dut, 5)
    dut.start.value = 0

    # Increase the count for more tests
    test_count = 3
    for idx in range(test_count):
        arr = [random.randint(0, (1 << DATA_WIDTH)-1) for _ in range(ARRAY_SIZE)]
        cocotb.log.debug(f"Random: {arr}!")
        await run_test_case(f"Random {idx}", dut, arr, DATA_WIDTH, ARRAY_SIZE, 0)

    # Worst case scenario for BST (descending)
    arr = random.sample(range(1 << DATA_WIDTH), ARRAY_SIZE)
    cocotb.log.debug(f"Worst case scenario for BST (descending): {sorted(arr)}!")
    await run_test_case(f" Worst case scenario (descending)", dut, sorted(arr), DATA_WIDTH, ARRAY_SIZE, 1)
    
    # Worst case scenario for BST (ascending)
    name = "Worst case scenario (ascending)"
    arr = random.sample(range(1 << DATA_WIDTH), ARRAY_SIZE)
    cocotb.log.debug(f"Worst case scenario for BST (ascending): {sorted(arr, reverse=True)}!")
    await run_test_case(f"{name}", dut, sorted(arr, reverse=True), DATA_WIDTH, ARRAY_SIZE, 1)
    
    # Best case scenario for BST (Balanced Tree)
    elements = sorted(random.sample(range(1 << DATA_WIDTH), ARRAY_SIZE))
    balanced_array = lambda nums: nums[len(nums)//2:len(nums)//2+1] + balanced_array(nums[:len(nums)//2]) + balanced_array(nums[len(nums)//2+1:]) if nums else []
    balanced_tree_array = balanced_array(elements)
    cocotb.log.debug(f"Balanced_tree_array: {balanced_tree_array}!")
    await run_test_case(f"Balanced Tree", dut, balanced_tree_array, DATA_WIDTH, ARRAY_SIZE, 0)

    # Mixed min/max pattern 
    arr = [0 if i % 2 == 0 else (1 << DATA_WIDTH)-1 for i in range(ARRAY_SIZE)]
    cocotb.log.debug(f"Mixed min/max pattern: {arr}!")
    await run_test_case("Min-Max Alternating", dut, arr, DATA_WIDTH, ARRAY_SIZE, 0)

    # All duplicates - check for latency as it traverses only left tree similar to sorted input array in ascending order
    random_val = random.randint(0, (1 << DATA_WIDTH)-1)
    cocotb.log.debug(f"All duplicates: {[random_val] * ARRAY_SIZE}!")
    await run_test_case("All Duplicates", dut, [random_val] * ARRAY_SIZE, DATA_WIDTH, ARRAY_SIZE, 1)


async def reset_dut(dut, duration):
    dut.reset.value = 1
    for _ in range(duration):
        await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

async def clock(dut, clk_period):
        while True:
            dut.clk.value = 0
            await Timer(clk_period/2, units='ns')
            dut.clk.value = 1
            await Timer(clk_period/2, units='ns')

async def run_test_case(name, dut, input_array, data_width, array_size, sort):
        cocotb.log.info(f"Running Test: {name}")
        packed_input = 0
        for idx, val in enumerate(input_array):
            packed_input |= (val << (idx * data_width))
        dut.data_in.value = packed_input
     
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.done.value == 1:
                break

        cocotb.log.debug(f"Total Latency {cycle_count}")
        out_data_val = int(dut.sorted_out.value)

        output_array = [ (out_data_val >> (i * data_width)) & ((1 << data_width) - 1) for i in range(array_size)]
        expected_output = sorted(input_array)
        
        assert output_array == expected_output, f"[{name}] Output incorrect. Got: {output_array}, Expected: {expected_output}"
        
        # Check for Latency
        if ((sort) or (array_size == 1)):
            cocotb.log.debug(f"{name}: Total Latency for BUILD_TREE and SORT_TREE FSM: {cycle_count}, expected : {calculate_latency(array_size, 1)}")
            assert calculate_latency(array_size, 1) == cycle_count, f"[{name}] Latency incorrect. Got: {cycle_count}, Expected: {calculate_latency(array_size, 1)}"

        cocotb.log.info(f"Test {name} passed.")
