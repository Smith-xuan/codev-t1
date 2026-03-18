import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly , Timer

import harness_library as hrs_lb
import random

@cocotb.test()
async def test_bcd_adder(dut):

    # Initialize the DUT signals with default 0
    await hrs_lb.dut_init(dut)

    # Randomly apply inputs and monitor outputs
    for _ in range(10):
        a_value = random.randint(0, 9)  # BCD range [0-9]
        b_value = random.randint(0, 9)  # BCD range [0-9]
        print(f"Performing_write_operation:: a_value = {a_value}, b_value = {b_value}")
        
        # Assign values to DUT
        dut.a.value = a_value
        dut.b.value = b_value

        # Wait for the 10ns
        await Timer(10, units='ns')

        # Check the output
        expected_sum = (a_value + b_value) % 10
        expected_cout = 1 if (a_value + b_value) >= 10 else 0

        sum_value  = int(dut.sum.value)
        cout_value = int(dut.cout.value)


        print(f"Performing_reading_operation:: sum_value = {sum_value}, cout_value = {cout_value}")
        # Check if the output matches the expected results
        assert sum_value == expected_sum, f"Sum mismatch: expected {expected_sum}, Got {sum_value}"
        assert cout_value == expected_cout, f"Cout mismatch: expected {expected_cout}, Got {cout_value}"
        
        # Wait before next test iteration
        await Timer(10, units='ns')