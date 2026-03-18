import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Timer

import harness_library as hrs_lb
import random


@cocotb.test()
async def test_Data_Reduction(dut):
    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    DATA_COUNT = int(dut.DATA_COUNT.value)
    REDUCTION_OP = int(dut.REDUCTION_OP.value)

    OPERATION_NAMES = {
        0b000: "AND",
        0b001: "OR",
        0b010: "XOR",
        0b011: "NAND",
        0b100: "NOR",
        0b101: "XNOR",
        0b110: "DEFAULT_AND",  
        0b111: "DEFAULT_AND"   
    }
    TOTAL_INPUT_WIDTH = DATA_WIDTH * DATA_COUNT

    # Initialize the DUT signals with default 0
    await hrs_lb.dut_init(dut)
    dut._log.info(f"Testing with REDUCTION_OP={REDUCTION_OP}, DATA_WIDTH={DATA_WIDTH}, DATA_COUNT={DATA_COUNT}")

    await Timer(10, units="ns")

    # Generate multiple test cases
    for _ in range(3):  # Run 3 test cases
        # Generate random input data
        data = [
            [random.randint(0, 1) for _ in range(DATA_WIDTH)]
            for _ in range(DATA_COUNT)
        ]

        # Flatten input data into a single integer for data_in
        data_flat = sum(
            (data_bit << (i * DATA_WIDTH + bit))
            for i, data_word in enumerate(data)
            for bit, data_bit in enumerate(data_word)
        )
        dut.data_in.value = data_flat

        await Timer(10, units="ns")

        # Calculate expected output for the given operation
        expected_output = []
        for j in range(DATA_WIDTH):
            bit_column = [data[i][j] for i in range(DATA_COUNT)]

            if OPERATION_NAMES[REDUCTION_OP] in ["AND", "NAND", "DEFAULT_AND"]:
                result = all(bit_column)
            elif OPERATION_NAMES[REDUCTION_OP] in ["OR", "NOR"]:
                result = any(bit_column)
            elif OPERATION_NAMES[REDUCTION_OP] in ["XOR", "XNOR"]:
                result = sum(bit_column) % 2
            else:
                raise ValueError(f"Invalid REDUCTION_OP: {REDUCTION_OP}")

            if OPERATION_NAMES[REDUCTION_OP] in ["NAND", "NOR", "XNOR"]:
                result = not result

            expected_output.append(int(result))

        # Convert expected output to integer
        expected_output_value = 0
        for idx, bit in enumerate(expected_output):
            expected_output_value |= (bit << idx)

        # Check the DUT output against the expected output
        reduced_data_out_value = int(dut.reduced_data_out.value)
        assert reduced_data_out_value == expected_output_value, (
            f"Test failed for input data {data}. "
            f"Expected: {expected_output_value}, "
            f"Got: {reduced_data_out_value}."
        )
        dut._log.info(f"Test passed for input data {data}. "
                      f"Expected: {expected_output_value}, "
                      f"Got: {reduced_data_out_value}.")
