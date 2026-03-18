import cocotb
import random
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.clock import Clock
import random

# Constants
DEPTH = 256  # Buffer depth must match the RTL configuration

# Reset routine for the DUT
async def reset_dut(dut):
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

# Data Validation Test
@cocotb.test()
async def data_validation_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    data_written = []
    write_cycles = 50  # Adjust as necessary for depth of the buffer

    # Writing data to the buffer
    for i in range(write_cycles):
        if not dut.buffer_full.value:
            dut.write_enable.value = 1
            data = random.randint(0, 255)
            dut.data_in.value = data
            data_written.append(data)
            await RisingEdge(dut.clk)
        dut.write_enable.value = 0

    await ClockCycles(dut.clk, 10)  # Delay to allow all writes to complete

    # Reading back and verifying data
    for data in data_written:
        if not dut.buffer_empty.value:
            dut.read_enable.value = 1
            await RisingEdge(dut.clk)
            assert dut.data_out.value == data, f"Data mismatch: expected {data}, got {dut.data_out.value}"
        dut.read_enable.value = 0

# Buffer Alternation Test
@cocotb.test()
async def buffer_alternation_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    initial_select = dut.buffer_select.value
    write_data = 0

    # Ensure we perform enough operations to potentially cause a toggle
    for _ in range(DEPTH * 2):  # Ensuring multiple cycles to observe toggling
        dut.write_enable.value = 1
        dut.read_enable.value = 1
        dut.data_in.value = write_data
        write_data = (write_data + 1) % 256
        await RisingEdge(dut.clk)

        # Check for toggle on wrap-around
        if _ > DEPTH and dut.buffer_select.value != initial_select:
            break

    assert dut.buffer_select.value != initial_select, "Buffer select did not toggle as expected"

# Stress Testing for simultaneous read and write operations
@cocotb.test()
async def stress_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    for _ in range(1000):
        dut.write_enable.value = random.getrandbits(1)
        dut.read_enable.value = random.getrandbits(1)
        if dut.write_enable.value and not dut.buffer_full.value:
            dut.data_in.value = random.randint(0, 255)
        await RisingEdge(dut.clk)
async def reset_dut(dut):
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def async_reset_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
    assert dut.buffer_empty.value == 1, "Buffer should be empty after reset"

@cocotb.test()
async def random_operation_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)
    for _ in range(500):
        dut.write_enable.value = random.getrandbits(1)
        dut.read_enable.value = random.getrandbits(1)
        if dut.write_enable.value:
            dut.data_in.value = random.randint(0, 255)
        await RisingEdge(dut.clk)

@cocotb.test()
async def boundary_condition_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Fill the buffer completely
    dut.write_enable.value = 1
    full_flag = False
    for i in range(DEPTH):  # DEPTH is assumed to be the size of the buffer, which is 256
        dut.data_in.value = i % 256
        await FallingEdge(dut.clk)
        if dut.buffer_full.value:
            full_flag = True
            break
    assert full_flag, "Buffer never reported full when expected."
    dut.write_enable.value = 0

    # Confirm that the buffer is indeed full
    assert dut.buffer_full.value, "Buffer should be full now."

    # Start reading and empty the buffer
    dut.read_enable.value = 1
    empty_flag = False
    for i in range(DEPTH):
        await FallingEdge(dut.clk)
        if dut.buffer_empty.value:
            empty_flag = True
            break
    assert empty_flag, "Buffer never reported empty when expected."

    # Confirm that the buffer is indeed empty after all reads
    assert dut.buffer_empty.value, "Buffer should be empty now."

    # Stop reading
    dut.read_enable.value = 0
