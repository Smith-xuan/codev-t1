import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import math 
import random

def generate_random_with_constraints(data_width, input_array):
    """
    Generate a random number within the range [0, 2^data_width - 1] 
    that is not present in input_array.
    """
    range_limit = (1 << data_width) - 1  # 2^data_width - 1
    input_set = set(input_array)  # Convert array to a set for fast lookups
    
    while True:
        random_number = random.randint(0, range_limit)
        if random_number not in input_set:
            return random_number

@cocotb.test()
async def test_search_bst(dut):
    """Cocotb testbench for the search_binary_search_tree module."""
    left_child = []
    right_child = []
    packed_left_child = 0
    packed_right_child = 0
    packed_keys = 0
    run = 0

    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    ARRAY_SIZE = int(dut.ARRAY_SIZE.value)
    
    MAX_LATENCY = (4 * ARRAY_SIZE + 3)  # Timeout for maximum latency

    # Initialize the clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset the DUT
    dut.reset.value = 1
    await Timer(20, units="ns")
    dut.reset.value = 0

    for i in range(4):
        await RisingEdge(dut.clk)

    # Test Case 1: Empty tree
    dut.search_key.value = 10  # Key to search
    dut.keys.value = 0; 

    for i in range(ARRAY_SIZE):
        left_child.append(2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1)
        right_child.append(2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1)

    for idx, val in enumerate(left_child):
        packed_left_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
    dut.left_child.value = packed_left_child
 

    for idx, val in enumerate(right_child):
        packed_right_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
    dut.right_child.value = packed_right_child

    dut.root.value = 2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    #await RisingEdge(dut.search_invalid.value)

    cycle_count = 0
    while True:
        await RisingEdge(dut.clk)
        cycle_count += 1
        if dut.complete_found.value == 1 or dut.search_invalid.value == 1:
            break

    print('key_position', dut.key_position.value)
    print('search_invalid', dut.key_position.value)

    assert ((dut.complete_found.value == 0) and dut.key_position.value == 2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1) , "Failed: Tree is empty; search_key should not be found"

    assert (dut.search_invalid.value == 1) , "Failed: Tree is empty; search_key should not be found, search_invalid not set"

    for i in range(2):
        await RisingEdge(dut.clk)

    # Test Case 2: Non-empty BST
    if (ARRAY_SIZE == 10 and DATA_WIDTH == 16):
        keys = [58514, 50092, 48887, 48080, 5485, 5967, 19599, 23938, 34328, 42874]
        right_child = [31, 31, 31, 31, 5, 6, 7, 8, 9, 31]
        left_child = [1, 2, 3, 4, 31, 31, 31, 31, 31, 31]
        run = 1
        expected_latency_smallest = 8
        expected_latency_largest = (ARRAY_SIZE - 1) * 2 + 2  + 2
    elif (ARRAY_SIZE == 15 and DATA_WIDTH == 6):
        keys = [9, 14, 15, 17, 19, 21, 30, 32, 35, 40, 46, 47, 48, 49, 50]
        left_child = [31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31]
        right_child = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 31]
        run = 1
        expected_latency_smallest = 3
        expected_latency_largest = (ARRAY_SIZE - 1) * 2 + 2 + 2
    elif (ARRAY_SIZE == 15 and DATA_WIDTH == 32):
        keys = [200706183, 259064287, 811616460, 956305578, 987713153, 1057458493, 1425113391, 1512400858, 2157180141, 2322902151, 2683058769, 2918411874, 2982472603, 3530595430, 3599316877]
        keys = sorted(keys, reverse=True)
        right_child = [31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31]
        left_child = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 31]
        run = 1
        expected_latency_smallest = (ARRAY_SIZE - 1) + 2 + 2
        expected_latency_largest = (ARRAY_SIZE - 1) * 2 + 2 + 2
    elif (ARRAY_SIZE == 5 and DATA_WIDTH == 6):
        keys = [1, 20, 0, 61, 5]
        left_child = [2,4,15,15,15]
        right_child = [1,3,15,15,15]
        run = 1
        expected_latency_smallest = 5 
        expected_latency_largest = (ARRAY_SIZE - 1)*2 + 2 

    
    if run == 1:
        print('keys', keys)
        print('left_child', left_child)
        print('right_child', right_child)
        print('Test case 2: Random key')
        dut.start.value = 1
        dut.search_key.value = random.choice(keys)
        packed_left_child = 0
        packed_right_child = 0
        
        for idx, val in enumerate(keys):
            packed_keys |= (val << (idx * DATA_WIDTH))
        
        dut.keys.value = packed_keys

        for idx, val in enumerate(left_child):
            packed_left_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
    
        dut.left_child.value = packed_left_child

        for idx, val in enumerate(right_child):
            packed_right_child |= (val << (idx * (math.ceil(math.log2(ARRAY_SIZE)) + 1)))
        dut.right_child.value = packed_right_child

    
        dut.root.value = 0
        await RisingEdge(dut.clk)
        dut.start.value = 0

        found = dut.complete_found.value
        expected_position = reference_model(dut.search_key.value.integer, keys)

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_found.value == 1:
                break
        
        print('key_value', dut.search_key.value.integer)
        print('key_position', dut.key_position.value.integer)
    
        assert dut.complete_found.value and dut.key_position.value.integer == expected_position, \
            f"Failed: Key {dut.search_key.value} should be found at position {expected_position}."
        
        for i in range(2):
            await RisingEdge(dut.clk)

        # Test Case 3: Key not in BST
        dut.start.value = 1

        print('Test case 3: not in key')

        dut.search_key.value = generate_random_with_constraints(DATA_WIDTH, keys)  # Key not in BST
       
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_found.value == 1 or dut.search_invalid.value == 1:
                break

        print('key_value', dut.search_key.value.integer)
        print('key_position', dut.key_position.value.integer)
    
        print('search_invalid', dut.search_invalid.value)
        
        assert ((dut.complete_found.value == 0) and dut.key_position.value == 2**(math.ceil(math.log2(ARRAY_SIZE)) + 1)-1) , \
            f"Failed: Key {dut.search_key.value} should not be found in the BST."

        assert (dut.search_invalid.value == 1) , "Failed: Search_key should not be found, search_invalid not set"

        for i in range(2):
            await RisingEdge(dut.clk)

        # Test Case 4: Smallest key in BST
        print('Test case 4: Smallest key')
        
        dut.start.value = 1
        dut.search_key.value = sorted(keys)[0]  # Smallest key
       
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_found.value == 1:
                break
        
        print('key_value', dut.search_key.value.integer)
        print('key_position', dut.key_position.value.integer)

        cocotb.log.debug(f"Total Latency : {cycle_count}, expected : {expected_latency_smallest}")
        assert expected_latency_smallest == cycle_count, f"Latency incorrect. Got: {cycle_count}, Expected: {expected_latency_smallest}"

        expected_position = reference_model(dut.search_key.value.integer, keys)
        assert dut.complete_found.value == 1 and dut.key_position.value.integer == expected_position, \
            f"Failed: Smallest key {dut.search_key.value} should be at position {expected_position}."

        for i in range(2):
            await RisingEdge(dut.clk)

        # Test Case 5: Largest key in BST
        print('Test case 5: Largest key')
        
        dut.start.value = 1
        dut.search_key.value = sorted(keys)[ARRAY_SIZE-1]  # Largest key
        
        await RisingEdge(dut.clk)
        dut.start.value = 0

        cycle_count = 0
        while True:
            await RisingEdge(dut.clk)
            cycle_count += 1
            if dut.complete_found.value == 1:
                break

        cocotb.log.debug(f"Total Latency : {cycle_count}, expected : {expected_latency_largest}")
        assert expected_latency_largest == cycle_count, f"Latency incorrect. Got: {cycle_count}, Expected: {expected_latency_largest}"

    
        expected_position = reference_model(dut.search_key.value, keys)
        assert dut.complete_found.value and dut.key_position.value.integer == expected_position, \
            f"Failed: Largest key {dut.search_key.value} should be at position {expected_position}."

        cocotb.log.info("All test cases passed!")

# Reference model
def reference_model(search_key, keys):
    """Sort the keys and find the position of the search key."""
    sorted_keys = sorted(keys)
    if search_key in sorted_keys:
        return sorted_keys.index(search_key)
    else:
        return -1
