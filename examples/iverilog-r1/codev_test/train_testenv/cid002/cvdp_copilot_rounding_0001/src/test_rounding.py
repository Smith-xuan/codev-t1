import os
import cocotb
from cocotb.triggers import Timer

# Constants for rounding modes
RNE = 0b000  # Round to Nearest, Even
RTZ = 0b001  # Round Toward Zero
RUP = 0b010  # Round Toward Positive Infinity
RDN = 0b011  # Round Toward Negative Infinity
RMM = 0b100  # Round to Nearest with Max Magnitude

@cocotb.test()
async def rounding_test(dut):
    """
    Cocotb testbench for the rounding module.
    """

    # Dynamically determine the WIDTH from the DUT's in_data signal
    WIDTH = len(dut.in_data)
    ALL_ONES = (1 << WIDTH) - 1
    ALL_ZERO = 0

    def compute_expected_math(t_in, t_sign, t_roundin, t_stickyin, t_rm):
        exp_inexact = t_roundin or t_stickyin
        exp_out = t_in
        rounding_up = False

        if t_rm == RNE:  # Round to Nearest, Even
            if t_roundin:
                rounding_up = t_stickyin or (t_in & 1)
        elif t_rm == RTZ:  # Round Toward Zero
            rounding_up = False
        elif t_rm == RUP:  # Round Toward Positive Infinity
            rounding_up = not t_sign and exp_inexact
        elif t_rm == RDN:  # Round Toward Negative Infinity
            rounding_up = t_sign and exp_inexact and t_in != ALL_ONES
        elif t_rm == RMM:  # Round to Max Magnitude
            rounding_up = t_roundin

        if rounding_up:
            exp_out = t_in + 1

        exp_out &= ALL_ONES
        exp_cout = (t_in == ALL_ONES and rounding_up)
        exp_r_up = rounding_up
        return exp_out, exp_inexact, exp_cout, exp_r_up

    pass_count = 0
    fail_count = 0

    async def run_test_case(t_in, t_sign, t_roundin, t_stickyin, t_rm):
        nonlocal pass_count, fail_count

        # Mask input to WIDTH bits
        t_in = t_in & ALL_ONES

        dut.in_data.value = t_in
        dut.sign.value = t_sign
        dut.roundin.value = t_roundin
        dut.stickyin.value = t_stickyin
        dut.rm.value = t_rm

        await Timer(1, units="ns")  # Allow outputs to settle

        # Compute expected results using the new function
        exp_out, exp_inexact, exp_cout, exp_r_up = compute_expected_math(t_in, t_sign, t_roundin, t_stickyin, t_rm)

        try:
            assert dut.out_data.value == exp_out, f"OUT_DATA MISMATCH: Expected {exp_out}, Got {int(dut.out_data.value)}"
            assert dut.inexact.value == exp_inexact, f"INEXACT MISMATCH: Expected {exp_inexact}, Got {int(dut.inexact.value)}"
            assert dut.cout.value == exp_cout, f"COUT MISMATCH: Expected {exp_cout}, Got {int(dut.cout.value)}"
            assert dut.r_up.value == exp_r_up, f"R_UP MISMATCH: Expected {exp_r_up}, Got {int(dut.r_up.value)}"
            pass_count += 1

            # Determine hex width for logging
            hex_width = (WIDTH + 3) // 4
            dut._log.info(
                f"PASS: in_data={t_in:0{hex_width}X}, rm={t_rm:03b}, sign={t_sign}, "
                f"roundin={t_roundin}, stickyin={t_stickyin}"
            )
        except AssertionError as e:
            fail_count += 1
            dut._log.error(f"FAIL: {e}")

    # Original test cases
    test_cases = [
        (ALL_ONES,      0, 0, 0, RNE),
        (ALL_ONES >> 1, 0, 1, 0, RNE),
        (ALL_ZERO,      0, 1, 1, RNE),
        (ALL_ONES,      1, 1, 0, RDN),
        (ALL_ONES >> 2, 0, 1, 1, RUP),
        (0x01,          0, 1, 0, RMM),
        (0x00,          1, 1, 1, RTZ),
        (ALL_ONES - 1,  0, 1, 1, RUP),
    ]

    # Additional edge cases
    test_cases += [
        (ALL_ZERO, 0, 1, 1, RNE),
        (ALL_ZERO, 1, 1, 1, RTZ),
        (ALL_ONES, 0, 1, 1, RUP),
        (ALL_ONES, 1, 1, 1, RDN),
        (0x000001, 0, 1, 0, RNE),   # Smallest positive value, RNE
        (0x000001, 1, 1, 0, RDN),   # Smallest positive value, RDN
        (0x000001, 0, 1, 1, RMM),   # Smallest positive with sticky, RMM
        (0x7FFFFF, 0, 1, 0, RUP),   # Maximum positive non-overflow, RUP
        (0x800000, 1, 1, 0, RDN),   # Negative middle value, RDN
        (0x800000, 0, 0, 0, RTZ),   # Negative middle value, RTZ, no rounding
        (0x000000, 0, 1, 1, RUP),   # Zero input, positive rounding, RUP
        (0x000000, 1, 1, 1, RDN),   # Zero input, negative rounding, RDN
        (0x00000F, 0, 1, 0, RNE),   # Low positive with round bit set, RNE
        (0xFFFFFF, 1, 1, 1, RMM),   # Negative max value, RMM
        (0x800001, 1, 1, 1, RNE),   # Negative near middle, RNE
    ]

    # Run all test cases
    for t_in, t_sign, t_roundin, t_stickyin, t_rm in test_cases:
        await run_test_case(t_in, t_sign, t_roundin, t_stickyin, t_rm)

    # Final report
    dut._log.info(f"Test completed: Passed = {pass_count}, Failed = {fail_count}")
    assert fail_count == 0, f"Some tests failed: {fail_count} failures."
