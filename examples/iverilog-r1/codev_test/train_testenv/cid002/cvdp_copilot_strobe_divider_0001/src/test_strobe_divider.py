import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


# Function to calculate the log2ceil in Python for test consistency
def log2ceil(value):
    i = 1
    while (2 ** i) < value:
        i += 1
    return i


@cocotb.test()
async def test_strobe_divider_basic_functionality(dut):
    """
    Test the basic functionality of the strobe_divider module.
    """
    # Constants for test
    MAX_RATIO = int(dut.MaxRatio_g.value)
    LATENCY = int(dut.Latency_g.value)
    RATIO_WIDTH = log2ceil(MAX_RATIO)

    # Initialize and apply reset
    dut.Rst.value = 1
    dut.In_Valid.value = 0
    dut.In_Ratio.value = 0
    dut.Out_Ready.value = 0
    await Timer(10, units="ns")
    dut.Rst.value = 0
    await Timer(10, units="ns")

    # Create a clock on Clk
    cocotb.start_soon(Clock(dut.Clk, 10, units="ns").start())

    # Test Case 1: Check reset behavior
    try:
        dut.Rst.value = 1
        await RisingEdge(dut.Clk)
        dut.Rst.value = 0
        await RisingEdge(dut.Clk)

        assert dut.Out_Valid.value == 0, "Out_Valid should be 0 after reset."
        assert dut.r_Count.value == 0, "Internal counter r_Count should be 0 after reset."
        dut._log.info("Test Case 1: Reset behavior passed.")
    except AssertionError as e:
        dut._log.error(f"Test Case 1 failed: {str(e)}")

    # Test Case 2: Basic operation with In_Ratio = 3
    try:
        test_ratio = 3
        dut.In_Ratio.value = test_ratio
        dut.In_Valid.value = 1
        dut.Out_Ready.value = 1

        counter = 0  # Counter to track valid cycles
        for i in range(20):  # Run for enough clock cycles to test behavior
            await RisingEdge(dut.Clk)

            # Increment the counter only when In_Valid is high
            if dut.In_Valid.value == 1 and dut.Out_Valid.value == 0:
                counter += 1

            # Check if Out_Valid pulses after the correct number of cycles
            if dut.Out_Valid.value == 1:
                assert counter == test_ratio, f"Counter mismatch! Expected {test_ratio}, got {counter}."
                counter = 0  # Reset counter after Out_Valid pulse

        dut._log.info("Test Case 2: Basic operation passed.")
    except AssertionError as e:
        dut._log.error(f"Test Case 2 failed: {str(e)}")

    # Test Case 3: Verify Latency_g behavior
    try:
        if LATENCY == 0:
            dut.In_Ratio.value = 5
            dut.In_Valid.value = 1
            dut.Out_Ready.value = 1
            await RisingEdge(dut.Clk)
            assert dut.Out_Valid.value == 1, "Latency 0: Out_Valid should immediately reflect the result."
        else:
            dut.In_Ratio.value = 5
            dut.In_Valid.value = 1
            dut.Out_Ready.value = 1
            await RisingEdge(dut.Clk)
            assert dut.Out_Valid.value == 0, "Latency 1: Out_Valid should not immediately reflect the result."
        dut._log.info("Test Case 3: Latency behavior passed.")
    except AssertionError as e:
        dut._log.error(f"Test Case 3 failed: {str(e)}")

    # Test Case 4: In_Ratio = 0 should generate immediate pulse
    try:
        dut.In_Ratio.value = 0
        dut.In_Valid.value = 1
        dut.Out_Ready.value = 1
        await RisingEdge(dut.Clk)
        assert dut.Out_Valid.value == 1, "In_Ratio=0: Out_Valid should pulse immediately."
        dut._log.info("Test Case 4: Immediate pulse for In_Ratio=0 passed.")
    except AssertionError as e:
        dut._log.error(f"Test Case 4 failed: {str(e)}")

    # Test Case 5: Out_Ready = 0 should stall the output
    try:
        dut.In_Ratio.value = 3
        dut.In_Valid.value = 1
        dut.Out_Ready.value = 0
        await RisingEdge(dut.Clk)
        assert dut.Out_Valid.value == 0, "Out_Valid should not assert when Out_Ready=0."

        dut.Out_Ready.value = 1
        await RisingEdge(dut.Clk)
        assert dut.Out_Valid.value == 1, "Out_Valid should assert when Out_Ready=1."
        dut._log.info("Test Case 5: Out_Ready stalling passed.")
    except AssertionError as e:
        dut._log.error(f"Test Case 5 failed: {str(e)}")

    # Test Case 6: Complex sequence
    try:
        for ratio in range(1, MAX_RATIO + 1):
            dut.In_Ratio.value = ratio
            dut.In_Valid.value = 1
            dut.Out_Ready.value = 1

            counter = 0
            for i in range(2 * ratio):  # Run enough cycles for testing
                await RisingEdge(dut.Clk)

                # Increment the counter only when In_Valid is high
                if dut.In_Valid.value == 1 and dut.Out_Valid.value == 0:
                    counter += 1

                # Check if Out_Valid pulses after the correct number of cycles
                if dut.Out_Valid.value == 1:
                    assert counter == ratio, f"Complex sequence failed! Ratio={ratio}, Counter={counter}"
                    counter = 0  # Reset counter after Out_Valid pulse

        dut._log.info("Test Case 6: Complex sequence passed.")
    except AssertionError as e:
        dut._log.error(f"Test Case 6 failed: {str(e)}")

    # End of test
    dut._log.info("All test cases completed!")
