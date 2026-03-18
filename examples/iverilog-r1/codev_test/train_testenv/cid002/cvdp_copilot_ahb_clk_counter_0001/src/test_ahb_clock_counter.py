
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import math

@cocotb.test()
async def test_ahb_clock_counter(dut):
    """Test AHB Clock Counter module functionality."""

    # Start clock with a period of 10 ns
    cocotb.start_soon(Clock(dut.HCLK, 10, units='ns').start())

    # Reset the design
    dut.HRESETn.value = 1
    await Timer(5, units='ns')
    dut.HRESETn.value = 0
    await Timer(10, units='ns')
    dut.HRESETn.value = 1

    # Initialize inputs
    dut.HSEL.value = 0
    dut.HWRITE.value = 0
    dut.HREADY.value = 1
    dut.HADDR.value = 0
    dut.HWDATA.value = 0

    # Wait for the reset to complete
    await RisingEdge(dut.HCLK)

    # Write to the ADDR_MAXCNT to set a maximum count
    max_count = 10
    assert max_count <= int(math.pow(2, int(dut.DATA_WIDTH.value)) - 1)
    dut.HSEL.value = 1
    dut.HWRITE.value = 1
    dut.HADDR.value = 0x10  # ADDR_MAXCNT
    dut.HWDATA.value = max_count
    await RisingEdge(dut.HCLK)

    # Start the counter by writing to ADDR_START
    dut.HADDR.value = 0x00  # ADDR_START
    dut.HWDATA.value = 1
    await RisingEdge(dut.HCLK)

    # Monitor the COUNTER output
    dut.HWRITE.value = 0  # Set to read mode
    counter_val = 0
    for i in range(max_count + 5):  # Run for max_count + extra cycles
        dut.HADDR.value = 0x08  # ADDR_COUNTER
        await RisingEdge(dut.HCLK)
        if 0 < counter_val < (max_count - 2):
            assert int(dut.HRDATA.value) == counter_val + 2
            assert int(dut.HRDATA.value) == int(dut.COUNTER.value)
            assert int(dut.HRESP.value) == 0 # HRESP returned ok
        counter_val = int(dut.HRDATA.value)
        print(f"Cycle {i}, Counter: {counter_val}")

        # Check for overflow
        dut.HADDR.value = 0x0C  # ADDR_OVERFLOW
        await RisingEdge(dut.HCLK)
        assert int(dut.HRESP.value) == 0  # HRESP returned ok
        overflow = int(dut.HRDATA.value)
        print(f"Cycle {i}, Overflow: {overflow}")

        if i == max_count:
            assert overflow == 1, "Overflow should occur at max_count"

    # Stop the counter by writing to ADDR_STOP
    dut.HWRITE.value = 1
    dut.HADDR.value = 0x04  # ADDR_STOP
    dut.HWDATA.value = 1
    await RisingEdge(dut.HCLK)

    # Verify the counter stops
    dut.HWRITE.value = 0  # Set to read mode
    for _ in range(3):  # Check for a few cycles
        dut.HADDR.value = 0x08  # ADDR_COUNTER
        await RisingEdge(dut.HCLK)
        assert int(dut.HRESP.value) == 0  # HRESP returned ok
        assert int(dut.HRDATA.value) == int(dut.COUNTER.value)
        stopped_value = int(dut.HRDATA.value)
        print(f"Stopped Counter: {stopped_value}")

    max_count = int(math.pow(2, int(dut.DATA_WIDTH.value)) - 1)

    # Restrict this part of the test to instances where the maximum counter value is small (<= 255),
    # to avoid excessively long runtimes for the test.
    if max_count <= 255:
        print("Running test for Max Counter")

        # Write to the ADDR_MAXCNT to set a maximum count
        dut.HSEL.value = 1
        dut.HWRITE.value = 1
        dut.HADDR.value = 0x10  # ADDR_MAXCNT
        dut.HWDATA.value = max_count
        await RisingEdge(dut.HCLK)
        print(f"Set the new Max Counter={max_count}")

        # Start the counter by writing to ADDR_START
        dut.HADDR.value = 0x00  # ADDR_START
        dut.HWDATA.value = 1
        await RisingEdge(dut.HCLK)
        print("Started the Counter")

        dut.HADDR.value = 0x08  # ADDR_COUNTER
        dut.HWRITE.value = 0  # Switch to read mode
        await RisingEdge(dut.HCLK)

        while int(dut.HRDATA.value) < max_count:
            print(f"Counter={int(dut.HRDATA.value)}")
            await RisingEdge(dut.HCLK)

        print("Reached the Max Counter")

        dut.HADDR.value = 0x0C  # ADDR_OVERFLOW
        await RisingEdge(dut.HCLK)
        assert int(dut.HRDATA.value) == 1


@cocotb.test()
async def test_ahb_clock_counter_overflow_persistence_and_post_overflow_reset(dut):
    """Test overflow persistence and counter behavior after an overflow."""

    # Start clock with a period of 10 ns
    cocotb.start_soon(Clock(dut.HCLK, 10, units='ns').start())

    # Reset the design
    dut.HRESETn.value = 1
    await Timer(5, units='ns')
    dut.HRESETn.value = 0
    await Timer(10, units='ns')
    dut.HRESETn.value = 1

    # Initialize inputs
    dut.HSEL.value = 0
    dut.HWRITE.value = 0
    dut.HREADY.value = 1
    dut.HADDR.value = 0
    dut.HWDATA.value = 0

    # Wait for reset to complete
    await RisingEdge(dut.HCLK)

    # Set a maximum count value
    max_count = 3
    dut.HSEL.value = 1
    dut.HWRITE.value = 1
    dut.HADDR.value = 0x10  # ADDR_MAXCNT
    dut.HWDATA.value = max_count
    await RisingEdge(dut.HCLK)

    # Start the counter
    dut.HADDR.value = 0x00  # ADDR_START
    dut.HWDATA.value = 1
    await RisingEdge(dut.HCLK)

    # Run until overflow
    dut.HWRITE.value = 0  # Switch to read mode
    for i in range(max_count + 1):
        # Read counter value
        dut.HADDR.value = 0x08  # ADDR_COUNTER
        await RisingEdge(dut.HCLK)
        assert int(dut.HRESP.value) == 0  # HRESP returned ok
        assert int(dut.HRDATA.value) == int(dut.COUNTER.value)
        counter_val = int(dut.HRDATA.value)
        print(f"Cycle {i}, Counter: {counter_val}")

        if i == max_count:
            # Check if overflow is set correctly
            dut.HADDR.value = 0x0C  # ADDR_OVERFLOW
            await RisingEdge(dut.HCLK)
            assert int(dut.HRESP.value) == 0 # HRESP returned ok
            overflow = int(dut.HRDATA.value)
            assert overflow == 1, "Overflow flag should be set at max_count"
            print("Overflow flag correctly set at max_count.")

    # Verify overflow flag persists
    dut.HADDR.value = 0x0C  # ADDR_OVERFLOW
    await RisingEdge(dut.HCLK)
    assert int(dut.HRESP.value) == 0  # HRESP returned ok
    overflow_persistent = int(dut.HRDATA.value)
    assert overflow_persistent == 1, "Overflow flag should persist until reset"

    # Perform manual reset of the overflow flag
    dut.HRESETn.value = 0
    await Timer(10, units='ns')
    dut.HRESETn.value = 1

    # Verify overflow flag is cleared after reset
    await RisingEdge(dut.HCLK)
    dut.HADDR.value = 0x0C  # ADDR_OVERFLOW
    await RisingEdge(dut.HCLK)
    assert int(dut.HRESP.value) == 0  # HRESP returned ok
    overflow_after_reset = int(dut.HRDATA.value)
    assert overflow_after_reset == 0, "Overflow flag should reset to 0 after manual reset"

    # Restart the counter and validate proper operation
    dut.HADDR.value = 0x00  # ADDR_START
    dut.HWDATA.value = 1
    dut.HWRITE.value = 1
    await RisingEdge(dut.HCLK)

    dut.HWRITE.value = 0
    dut.HADDR.value = 0x08  # ADDR_COUNTER
    for i in range(3):
        await RisingEdge(dut.HCLK)
        assert int(dut.HRESP.value) == 0  # HRESP returned ok
        assert int(dut.HRDATA.value) == int(dut.COUNTER.value)
        counter_val = int(dut.HRDATA.value)
        print(f"Cycle {i}, Counter After Restart: {counter_val}")
        assert counter_val == i, f"Counter mismatch after restart at cycle {i}: expected {i}, got {counter_val}"

    print("Test for overflow persistence and post-overflow behavior completed successfully.")

