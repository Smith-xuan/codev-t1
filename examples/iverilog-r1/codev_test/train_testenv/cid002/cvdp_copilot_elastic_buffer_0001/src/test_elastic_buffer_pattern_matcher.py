import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_elastic_buffer_pattern_matcher(dut):
    """Comprehensive test for elastic_buffer_pattern_matcher module."""
    # Create a clock with a period of 10 ns
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    WIDTH = len(dut.i_data)

    # Retrieve ERR_TOLERANCE from the DUT
    ERR_TOLERANCE = dut.ERR_TOLERANCE.value.integer

    # Initialize inputs
    dut.rst.value = 1  # Assert reset
    dut.i_data.value = 0
    dut.i_pattern.value = 0

    # Wait for a few clock cycles with reset asserted
    for _ in range(2):
        await RisingEdge(dut.clk)
        
    # Check that o_match is reset to 0
    observed_match = dut.o_match.value.integer
    assert dut.o_match.value == 0, (f"After reset deassertion, o_match should be 0 but got {observed_match}")

    dut.rst.value = 0  # Deassert reset
    await RisingEdge(dut.clk)


    # Corner Cases
    corner_cases = [
        {'i_data': 0x0000, 'i_pattern': 0x0000},
        {'i_data': (1 << WIDTH) - 1, 'i_pattern': (1 << WIDTH) - 1},
        {'i_data': 0x0000, 'i_pattern': (1 << WIDTH) - 1},
        {'i_data': (1 << WIDTH) - 1, 'i_pattern': 0x0000},
    ]

    for case in corner_cases:
        dut.i_data.value = case['i_data']
        dut.i_pattern.value = case['i_pattern']
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        observed_match = dut.o_match.value.integer
        hamming_distance = bin(case['i_data'] ^ case['i_pattern']).count('1')
        expected_match = int(hamming_distance < ERR_TOLERANCE)
        assert observed_match == expected_match, (
            f"Corner case failed: i_data={case['i_data']:0{WIDTH}b}, "
            f"i_pattern={case['i_pattern']:0{WIDTH}b}, "
            f"Hamming distance={hamming_distance}, "
            f"ERR_TOLERANCE={ERR_TOLERANCE}, "
            f"expected o_match={expected_match}, got {observed_match}"
        )

    # Edge Cases - One bit difference
    for i in range(WIDTH):
        i_data = 1 << i
        i_pattern = 0
        dut.i_data.value = i_data
        dut.i_pattern.value = i_pattern
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        observed_match = dut.o_match.value.integer
        hamming_distance = bin(i_data ^ i_pattern).count('1')
        expected_match = int(hamming_distance < ERR_TOLERANCE)
        assert observed_match == expected_match, (
            f"Edge case failed: i_data differs by one bit at position {i}, "
            f"Hamming distance={hamming_distance}, "
            f"ERR_TOLERANCE={ERR_TOLERANCE}, "
            f"expected o_match={expected_match}, got {observed_match}"
        )

    # Stress Test - Random patterns with random reset assertion
    num_random_tests = 1000
    for _ in range(num_random_tests):
        # Randomly assert reset
        if random.random() < 0.01:  # 1% chance to assert reset
            dut.rst.value = 1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            # Check that o_match is reset to 0
            assert dut.o_match.value == 0, (f"After reset deassertion, o_match should be 0 but got {observed_match}")
            dut.rst.value = 0
            await RisingEdge(dut.clk)

        i_data = random.getrandbits(WIDTH)
        i_pattern = random.getrandbits(WIDTH)
        dut.i_data.value = i_data
        dut.i_pattern.value = i_pattern
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        observed_match = dut.o_match.value.integer
        hamming_distance = bin(i_data ^ i_pattern).count('1')
        expected_match = int(hamming_distance < ERR_TOLERANCE)
        assert observed_match == expected_match, (
            f"Random test failed: i_data={i_data:0{WIDTH}b}, "
            f"i_pattern={i_pattern:0{WIDTH}b}, "
            f"Hamming distance={hamming_distance}, "
            f"ERR_TOLERANCE={ERR_TOLERANCE}, "
            f"expected o_match={expected_match}, got {observed_match}"
        )

    # Functional Coverage - Varying Hamming distances
    for hamming_distance in range(ERR_TOLERANCE + 2):
        i_data = random.getrandbits(WIDTH)
        if (hamming_distance >= WIDTH):
            hamming_distance = WIDTH - 1
        positions = random.sample(range(WIDTH), hamming_distance)
        i_pattern = i_data
        for pos in positions:
            i_pattern ^= 1 << pos
        dut.i_data.value = i_data
        dut.i_pattern.value = i_pattern
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        observed_match = dut.o_match.value.integer
        expected_match = int(hamming_distance < ERR_TOLERANCE)
        assert observed_match == expected_match, (
            f"Hamming distance test failed: i_data and i_pattern differ by "
            f"{hamming_distance} bits, ERR_TOLERANCE={ERR_TOLERANCE}, "
            f"expected o_match={expected_match}, got {observed_match}"
        )

    # Testing reset functionality specifically
    # Assert reset and check that o_match is reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.o_match.value == 0, (f"After reset deassertion, o_match should be 0 but got {observed_match}")

    # Deassert reset and check o_match behaves correctly
    dut.rst.value = 0
    i_data = random.getrandbits(WIDTH)
    i_pattern = i_data  # To ensure a match
    dut.i_data.value = i_data
    dut.i_pattern.value = i_pattern
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    observed_match = dut.o_match.value.integer
    expected_match = 1
    assert observed_match == expected_match, (
        f"After reset deassertion: i_data={i_data:0{WIDTH}b}, "
        f"i_pattern={i_pattern:0{WIDTH}b}, expected o_match={expected_match}, got {observed_match}"
    )

    # Full Functional Verification - All possible combinations
    if WIDTH <= 8:  # Limit exhaustive test to manageable sizes
        for i_data in range(1 << WIDTH):
            for i_pattern in range(1 << WIDTH):
                dut.i_data.value = i_data
                dut.i_pattern.value = i_pattern
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                observed_match = dut.o_match.value.integer
                hamming_distance = bin(i_data ^ i_pattern).count('1')
                expected_match = int(hamming_distance < ERR_TOLERANCE)
                assert observed_match == expected_match, (
                    f"Exhaustive test failed: i_data={i_data:0{WIDTH}b}, "
                    f"i_pattern={i_pattern:0{WIDTH}b}, "
                    f"Hamming distance={hamming_distance}, "
                    f"ERR_TOLERANCE={ERR_TOLERANCE}, "
                    f"expected o_match={expected_match}, got {observed_match}"
                )
