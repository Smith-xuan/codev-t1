import cocotb
from cocotb.triggers import Timer
import random


def binary_to_bcd(binary_in):
    """ Reference function for binary to BCD conversion using Double Dabble algorithm in Python """
    bcd_digits = [0, 0, 0]  # Initialize 3 BCD digits
    for i in range(8):  # 8-bit binary input
        # Add 3 if any BCD digit is 5 or greater
        if bcd_digits[2] >= 5:
            bcd_digits[2] += 3
        if bcd_digits[1] >= 5:
            bcd_digits[1] += 3
        if bcd_digits[0] >= 5:
            bcd_digits[0] += 3
        # Shift left and add next binary bit
        bcd_digits[2] = (bcd_digits[2] << 1) | (bcd_digits[1] >> 3)
        bcd_digits[1] = ((bcd_digits[1] << 1) & 0xF) | (bcd_digits[0] >> 3)
        bcd_digits[0] = ((bcd_digits[0] << 1) & 0xF) | ((binary_in >> (7 - i)) & 0x1)
    return (bcd_digits[2] << 8) | (bcd_digits[1] << 4) | bcd_digits[0]


@cocotb.test()
async def test_binary_to_bcd(dut):
    """ Test binary to BCD conversion using a reference model, with predefined and random test cases """
    
    # Define a range of predefined test cases
    test_cases = [0, 20, 99, 128, 255]
    
    # Generate additional random test cases
    random_test_cases = [random.randint(0, 255) for _ in range(5)]
    
    # Combine predefined and random test cases
    all_test_cases = test_cases + random_test_cases

    for binary_value in all_test_cases:
        # Apply the binary input to the DUT
        dut.binary_in.value = binary_value
        await Timer(10, units="ns")

        # Calculate the expected BCD output using the reference model
        expected_bcd = binary_to_bcd(binary_value)

        # Retrieve the actual BCD output from the DUT
        bcd_out = int(dut.bcd_out.value)

        # Check if the DUT output matches the expected BCD output
        assert bcd_out == expected_bcd, f"Test failed for binary {binary_value}: Expected {expected_bcd:012b}, got {bcd_out:012b}"
        
        # Print results
        dut._log.info(f"Binary Input: {binary_value} | Expected BCD Output: {expected_bcd:012b} | DUT BCD Output: {bcd_out:012b}")
