import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def reset_dut(dut):
    """Reset the DUT (Device Under Test)"""
    # Set all input signals to their default values
    dut.i_rst_b.value = 0
    dut.i_operand_a.value = 0
    dut.i_operand_b.value = 0
    dut.i_opcode.value = 0
    dut.i_key_in.value = 0

    # Wait for a clock cycle before releasing the reset
    await FallingEdge(dut.i_clk)
    dut.i_rst_b.value = 1
    await RisingEdge(dut.i_clk)


@cocotb.test()
async def test_alu_seq(dut):
    """
    Test the ALU sequential module with various operations and key validation.
    """
    # Start the clock for the DUT with a period of 10ns
    cocotb.start_soon(Clock(dut.i_clk, 10, units='ns').start())

    # Reset the DUT to ensure it starts from a known state
    await reset_dut(dut)

    # Internal security key from the ALU design
    internal_key = 0xAA

    # Helper function to apply stimulus and validate output
    async def apply_and_check(operand_a, operand_b, opcode, key, expected_result):
        dut.i_operand_a.value = operand_a
        dut.i_operand_b.value = operand_b
        dut.i_opcode.value = opcode
        dut.i_key_in.value = key
        await RisingEdge(dut.i_clk)  # Wait for one clock cycle
        await Timer(1, units='ns')  # Small delay to allow result propagation

        # Check the result
        assert dut.o_result.value == expected_result, (
            f"ALU failed for opcode {opcode} with operands "
            f"A={operand_a}, B={operand_b}, key={key}. "
            f"Expected: {expected_result}, Got: {int(dut.o_result.value)}"
        )

    # Test cases
    test_cases = [
        # Correct key, valid operations
        (3, 2, 0b000, internal_key, 5),  # ADD
        (5, 3, 0b001, internal_key, 2),  # SUB
        (2, 3, 0b010, internal_key, 6),  # MUL
        (0b1100, 0b1010, 0b011, internal_key, 0b1000),  # AND
        (0b1100, 0b1010, 0b100, internal_key, 0b1110),  # OR
        (0b1100, 0, 0b101, internal_key, 0b0011),  # NOT
        (0b1100, 0b1010, 0b110, internal_key, 0b0110),  # XOR
        (0b1100, 0b1010, 0b111, internal_key, 0b1001),  # XNOR
        
        # Incorrect key, output should be 0
        (3, 2, 0b000, 0x55, 0),  # ADD with wrong key
        (5, 3, 0b001, 0x55, 0),  # SUB with wrong key

        # Edge cases
        (0, 0, 0b000, internal_key, 0),  # ADD with zeros
        (0b1111, 0b0001, 0b000, internal_key, 0b10000),  # Overflow ADD
    ]

    # Apply test cases
    for operand_a, operand_b, opcode, key, expected_result in test_cases:
        await apply_and_check(operand_a, operand_b, opcode, key, expected_result)

    
    # Done
    dut._log.info("All ALU tests passed!")
