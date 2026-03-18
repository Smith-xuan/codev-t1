# test_compression_engine.py

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

# Import helper functions from harness_library.py
# Ensure that `harness_library.py` is in your Python path or the same directory.
from harness_library import reset_dut, dut_init

def extract_mantissa(num_i, exponent):
    """
    Extracts the mantissa from num_i based on the exponent.

    Args:
        num_i (int): The 24-bit input number.
        exponent (int): The exponent value (in decimal).

    Returns:
        int: The extracted mantissa.
    """
    if exponent >= 1:
        # Shift right by (exponent - 1) bits and mask the lower 12 bits
        mantissa_bits = (num_i >> (exponent - 1)) & 0xFFF
    else:
        # If exponent < 1, directly mask the lower 12 bits
        mantissa_bits = num_i & 0xFFF
    return mantissa_bits

def determine_exponent(num_i):
    """
    Determines the exponent based on the highest set bit in num_i[23:12].

    Args:
        num_i (int): The 24-bit input number.

    Returns:
        int: The calculated exponent.
    """
    for bit in reversed(range(12, 24)):
        if num_i & (1 << bit):
            return bit - 11  # Mapping based on the highest set bit position
    return 0  # If no bits are set in num_i[23:12]

@cocotb.test()
async def compression_engine_test(dut):
    """
    Comprehensive Test for the compression_engine module using all 22 unique test vectors.
    """
    # ----------------------------
    # Clock Generation
    # ----------------------------
    CLK_PERIOD = 10  # Clock period in nanoseconds
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())

    # ----------------------------
    # DUT Initialization and Reset
    # ----------------------------
    await dut_init(dut)  # Initialize DUT (reset inactive)
    await reset_dut(dut.reset, duration_ns=20, active=True)  # Assert reset
    await RisingEdge(dut.clk)  # Wait for one clock cycle during reset
    await RisingEdge(dut.clk)  # Additional clock cycle to ensure DUT is ready after reset

    # ----------------------------
    # Predefined Test Vectors
    # ----------------------------
    final_test_vectors = [
        (0x000000, 0),    # Test Case 0: All zeros
        (0x000001, 0),    # Test Case 1: Lowest bit set
        (0x000FFF, 0),    # Test Case 2: Lower 12 bits set
        (0x001000, 1),    # Test Case 3: Bit 12 set
        (0x00F000, 4),    # Test Case 4: Bits 15:12 set
        (0x0F0000, 8),    # Test Case 5: Bits 19:16 set
        (0x100000, 9),    # Test Case 6: Bit 20 set
        (0x800000, 12),   # Test Case 7: Highest bit set (Bit 23)
        (0x400000, 11),   # Test Case 8: Bit 22 set
        (0x200000, 10),   # Test Case 9: Bit 21 set
        (0x080000, 8),    # Test Case 10: Bit 19 set
        (0x040000, 7),    # Test Case 11: Bit 18 set
        (0x020000, 6),    # Test Case 12: Bit 17 set
        (0x010000, 5),    # Test Case 13: Bit 16 set
        (0x008000, 4),    # Test Case 14: Bit 15 set
        (0x004000, 3),    # Test Case 15: Bit 14 set
        (0x002000, 2),    # Test Case 16: Bit 13 set
        (0x000800, 0),    # Test Case 17: Bit 11 set
        (0x000400, 0),    # Test Case 18: Bit 10 set
        (0xABCDEF, 12),    # Test Case 19: Random value
        (0xFFFFF0, 12),    # Test Case 20: Multiple bits set
        (0xFFFFFF, 12),    # Test Case 21: Maximum value
    ]

    # ----------------------------
    # Execute Test Cases
    # ----------------------------
    failures = []

    for idx, (num_i, expected_exponent) in enumerate(final_test_vectors):
        # Calculate expected mantissa using the helper function
        expected_mantissa = extract_mantissa(num_i, expected_exponent)

        # Apply num_i to the DUT
        dut.num_i.value = num_i

        # Wait for two clock cycles to allow DUT to process the input
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # Read outputs from the DUT
        mantissa = dut.mantissa_o.value.integer
        exponent = dut.exponent_o.value.integer

        # Log the test case details
        dut._log.info(
            f"Test Case {idx}: num_i=0x{num_i:06X}, "
            f"Expected mantissa=0x{expected_mantissa:03X}, "
            f"Expected exponent={expected_exponent}, "
            f"Got mantissa=0x{mantissa:03X}, "
            f"Got exponent={exponent}"
        )

        # Validate mantissa
        if mantissa != expected_mantissa:
            failure_msg = (
                f"Test Case {idx} Failed: mantissa_o=0x{mantissa:03X} != expected 0x{expected_mantissa:03X}"
            )
            dut._log.error(failure_msg)
            failures.append(failure_msg)

        # Validate exponent
        if exponent != expected_exponent:
            failure_msg = (
                f"Test Case {idx} Failed: exponent_o={exponent} != expected {expected_exponent}"
            )
            dut._log.error(failure_msg)
            failures.append(failure_msg)

    # ----------------------------
    # Final Assertions
    # ----------------------------
    if failures:
        failure_summary = "\n".join(failures)
        assert False, f"{len(failures)} test case(s) failed:\n{failure_summary}"

    dut._log.info("All test cases passed successfully.")

@cocotb.test()
async def compression_engine_random_test(dut):
    """
    Randomized Test for the compression_engine module.
    Generates random test vectors to further validate the DUT's behavior.
    """
    # ----------------------------
    # Clock Generation
    # ----------------------------
    CLK_PERIOD = 10  # Clock period in nanoseconds
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())

    # ----------------------------
    # DUT Initialization and Reset
    # ----------------------------
    await dut_init(dut)  # Initialize DUT (reset inactive)
    await reset_dut(dut.reset, duration_ns=20, active=True)  # Assert reset
    await RisingEdge(dut.clk)  # Wait for one clock cycle during reset
    await RisingEdge(dut.clk)  # Additional clock cycle to ensure DUT is ready after reset

    # ----------------------------
    # Random Test Parameters
    # ----------------------------
    NUM_RANDOM_TESTS = 100  # Number of random test cases
    failures = []

    for idx in range(NUM_RANDOM_TESTS):
        # Generate a random 24-bit number for num_i
        num_i = random.randint(0, 0xFFFFFF)

        # Determine the exponent based on the highest set bit in num_i[23:12]
        exponent = determine_exponent(num_i)

        # Calculate expected mantissa using the helper function
        expected_mantissa = extract_mantissa(num_i, exponent)

        # Apply num_i to the DUT
        dut.num_i.value = num_i

        # Wait for two clock cycles to allow DUT to process the input
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # Read outputs from the DUT
        mantissa = dut.mantissa_o.value.integer
        exponent_o = dut.exponent_o.value.integer

        # Log the test case details
        dut._log.info(
            f"Random Test Case {idx}: num_i=0x{num_i:06X}, "
            f"Calculated exponent={exponent}, "
            f"Expected mantissa=0x{expected_mantissa:03X}, "
            f"Got mantissa=0x{mantissa:03X}, "
            f"Got exponent={exponent_o}"
        )

        # Validate mantissa
        if mantissa != expected_mantissa:
            failure_msg = (
                f"Random Test Case {idx} Failed: mantissa_o=0x{mantissa:03X} != expected 0x{expected_mantissa:03X}"
            )
            dut._log.error(failure_msg)
            failures.append(failure_msg)

        # Validate exponent
        if exponent_o != exponent:
            failure_msg = (
                f"Random Test Case {idx} Failed: exponent_o={exponent_o} != expected {exponent}"
            )
            dut._log.error(failure_msg)
            failures.append(failure_msg)

    # ----------------------------
    # Final Assertions
    # ----------------------------
    if failures:
        failure_summary = "\n".join(failures)
        assert False, f"{len(failures)} random test case(s) failed:\n{failure_summary}"

    dut._log.info("All random test cases passed successfully.")
