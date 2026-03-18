import cocotb
from cocotb.triggers import Timer
from random import randint

# Cocotb testbench for static branch predictor module
@cocotb.test()
async def test_static_branch_predict(dut):
    """Test Static Branch Predictor for different branch and jump scenarios."""

    # Define the test vectors based on the SystemVerilog run_test_case task
    test_vectors = [
        # Format: (test_instr, test_pc, test_register_operand, test_valid, expected_taken, expected_pc, expected_confidence, expected_exception, expected_branch_type, expected_offset, case_name)
        (0x8C218363, 0x00001000, 0x00000000, 1, 1, 0x000000C6, 90, 0, 0b011, 0xFFFFF0C6, "Branch taken, PC offset negative (BEQ)"),
        (0x6C2183E3, 0x00001000, 0x00000000, 1, 0, 0x00001EC6, 50, 0, 0b011, 0x00000EC6, "Branch not taken, PC offset positive (BEQ)"),
        (0x926CF16F, 0x00001000, 0x00000000, 1, 1, 0xFFFD0126, 100, 0, 0b001, 0xFFFCF126, "Jump taken, Negative Offset (JAL)"),
        (0x126CF16F, 0x00001000, 0x00000000, 1, 1, 0x000D0126, 100, 0, 0b001, 0x000CF126, "Jump taken, Positive Offset (JAL)"),
        (0xF63101E7, 0x00001000, 0x00000000, 1, 1, 0x00000F63, 100, 0, 0b010, 0xFFFFFF63, "Jump taken, Negative Offset (JALR)"),
        (0x763101E7, 0x00001000, 0x00000000, 1, 1, 0x00001763, 100, 0, 0b010, 0x00000763, "Jump taken, Positive Offset (JALR)"),
        (0x08040A63, 0x00001000, 0x00000000, 1, 0, 0x00001094, 50, 0, 0b011, 0x00000094, "Branch not taken, Positive Offset (C.BEQZ)"),
        (0x00000001, 0x00002000, 0x00000000, 0, 0, 0x00002000, 0, 0, 0b000, 0x00000000, "Invalid Fetch (Not Valid)"),
        (0xFE000E63, 0x00001000, 0x00000000, 1, 1, 0x000007FC, 90, 0, 0b011, 0xFFFFF7FC, "Branch taken, PC offset negative (BEQ)"),
    ]

    # Iterate through the test vectors and apply them to the DUT
    for (
        test_instr,
        test_pc,
        test_register_operand,
        test_valid,
        expected_taken,
        expected_pc,
        expected_confidence,
        expected_exception,
        expected_branch_type,
        expected_offset,
        case_name,
    ) in test_vectors:
        # Apply inputs
        dut.fetch_rdata_i.value = test_instr
        dut.fetch_pc_i.value = test_pc
        dut.register_addr_i.value = test_register_operand
        dut.fetch_valid_i.value = test_valid

        # Wait for the DUT to process the inputs
        await Timer(10, units="ns")

        # Capture the outputs
        actual_taken = dut.predict_branch_taken_o.value
        actual_pc = dut.predict_branch_pc_o.value
        actual_confidence = dut.predict_confidence_o.value
        actual_exception = dut.predict_exception_o.value
        actual_branch_type = dut.predict_branch_type_o.value
        actual_offset = dut.predict_branch_offset_o.value

        # Log the test case details
        dut._log.info(f"Running test case: {case_name}")
        dut._log.info(f"Inputs: Instr={test_instr:08X}, PC={test_pc:08X}, Valid={test_valid}, Register Operand={test_register_operand:08X}")
        dut._log.info(f"Expected: Taken={expected_taken}, PC={expected_pc:08X}, Confidence={expected_confidence}, Exception={expected_exception}, Branch Type={expected_branch_type}, Offset={expected_offset:08X}")
        dut._log.info(f"Actual: Taken={actual_taken}, PC={int(actual_pc):08X}, Confidence={int(actual_confidence)}, Exception={actual_exception}, Branch Type={actual_branch_type}, Offset={int(actual_offset):08X}")

        # Assertions to check if outputs match expectations
        assert actual_taken == expected_taken, f"{case_name} - Predict Branch Taken Mismatch: Expected {expected_taken}, Got {actual_taken}"
        assert int(actual_pc) == expected_pc, f"{case_name} - Predict Branch PC Mismatch: Expected {expected_pc:08X}, Got {int(actual_pc):08X}"
        assert int(actual_confidence) == expected_confidence, f"{case_name} - Confidence Mismatch: Expected {expected_confidence}, Got {int(actual_confidence)}"
        assert actual_exception == expected_exception, f"{case_name} - Exception Mismatch: Expected {expected_exception}, Got {actual_exception}"
        assert actual_branch_type == expected_branch_type, f"{case_name} - Branch Type Mismatch: Expected {expected_branch_type}, Got {actual_branch_type}"
        assert int(actual_offset) == expected_offset, f"{case_name} - Offset Mismatch: Expected {expected_offset:08X}, Got {int(actual_offset):08X}"

        # Wait before the next test case
        await Timer(10, units="ns")

    # Additional random test cases
    num_random_tests = 5  # Number of random tests to generate
    for i in range(num_random_tests):
        # Generate random values for instruction, PC, register operand, and valid signal
        test_instr = randint(0, 0xFFFFFFFF)
        test_pc = randint(0, 0xFFFFFFFF)
        test_register_operand = randint(0, 0xFFFFFFFF)
        test_valid = randint(0, 1)

        # Apply inputs
        dut.fetch_rdata_i.value = test_instr
        dut.fetch_pc_i.value = test_pc
        dut.register_addr_i.value = test_register_operand
        dut.fetch_valid_i.value = test_valid

        # Wait for the DUT to process the inputs
        await Timer(10, units="ns")

        # Capture the outputs
        actual_taken = dut.predict_branch_taken_o.value
        actual_pc = dut.predict_branch_pc_o.value

        # Log the random test case details
        dut._log.info(f"Random Test Case {i + 1}: Instr={test_instr:08X}, PC={test_pc:08X}, Valid={test_valid}")
        dut._log.info(f"Outputs: Taken={actual_taken}, PC={int(actual_pc):08X}")

        # No expected values for random tests, just log outputs
        await Timer(10, units="ns")

