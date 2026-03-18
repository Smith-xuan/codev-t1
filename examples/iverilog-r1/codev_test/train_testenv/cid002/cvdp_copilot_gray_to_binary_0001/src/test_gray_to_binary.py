import cocotb
from cocotb.triggers import Timer
import random
import time


@cocotb.test()
async def test_gray_to_binary(dut):
    """
    Enhanced Testbench for Gray Code to Binary Converter.
    """

    # Retrieve parameters dynamically from the DUT
    WIDTH = int(dut.WIDTH.value)  # Get the width of the Gray code input
    DEBUG_MODE = int(dut.DEBUG_MODE.value)  # Get DEBUG_MODE, default to 0

    # Function to compute Gray to Binary
    def compute_gray_to_binary(gray_in, WIDTH):
        """
        Compute binary value from Gray code.
        """
        binary_out = 0
        for i in range(WIDTH - 1, -1, -1):  # From MSB to LSB
            if i == WIDTH :  # MSB is directly assigned
                binary_out |= (gray_in >> i) & 1
            else:  # XOR subsequent bits
                binary_out |= (((binary_out >> (i + 1)) & 1) ^ ((gray_in >> i) & 1)) << i
        return binary_out

    # Function to verify parity
    def compute_parity(binary_value):
        return bin(binary_value).count('1') % 2  # Even parity (0 = even, 1 = odd)

    # Test function
    async def run_test_case(gray_in):
        start_time = time.time()  # Start execution timer

        # Apply input to DUT
        dut.gray_in.value = gray_in
        await Timer(1, units="ns")  # Wait for computation to settle

        # Compute expected outputs
        expected_binary = compute_gray_to_binary(int(gray_in), WIDTH)
        expected_parity = compute_parity(expected_binary)
        expected_debug_mask = (~expected_binary) & ((1 << WIDTH) - 1) if DEBUG_MODE else 0

        # Assertions
        assert dut.binary_out.value == expected_binary, (
            f"Mismatch for Gray Input: {gray_in:0{WIDTH}b} | "
            f"Expected Binary: {expected_binary:0{WIDTH}b}, Got: {int(dut.binary_out.value):0{WIDTH}b}"
        )
        assert dut.parity.value == expected_parity, (
            f"Parity Mismatch for Gray Input: {gray_in:0{WIDTH}b} | "
            f"Expected: {expected_parity}, Got: {int(dut.parity.value)}"
        )
        assert dut.debug_mask.value == expected_debug_mask, (
            f"Debug Mask Mismatch for Gray Input: {gray_in:0{WIDTH}b} | "
            f"Expected: {expected_debug_mask:0{WIDTH}b}, Got: {int(dut.debug_mask.value):0{WIDTH}b}"
        )

        dut._log.info(
            f"Test Passed for Gray Input: {gray_in:0{WIDTH}b} | "
            f"Binary Output: {int(dut.binary_out.value):0{WIDTH}b} | "
            f"Parity: {int(dut.parity.value)} | "
            f"Debug Mask: {int(dut.debug_mask.value):0{WIDTH}b}"
        )

    # Predefined test cases
    predefined_cases = [
        0b0000, 0b0001, 0b0011, 0b0010,
        0b0110, 0b0111, 0b0101, 0b0100,
        0b1100, 0b1101
    ]

    # Run predefined test cases
    dut._log.info(f"Running predefined test cases with WIDTH={WIDTH} and DEBUG_MODE={DEBUG_MODE}")
    for gray_in in predefined_cases:
        await run_test_case(gray_in)

    # Run random test cases
    dut._log.info("Running random test cases")
    for _ in range(10):  # Test 32 random cases for better coverage
        gray_in = random.randint(0, (1 << WIDTH) - 1)  # Generate random Gray code
        await run_test_case(gray_in)

    # Test edge cases
    dut._log.info("Running edge case tests")
    edge_cases = [0, (1 << WIDTH) - 1]  # Test minimum and maximum values
    for gray_in in edge_cases:
        await run_test_case(gray_in)

    dut._log.info("All tests completed successfully!")