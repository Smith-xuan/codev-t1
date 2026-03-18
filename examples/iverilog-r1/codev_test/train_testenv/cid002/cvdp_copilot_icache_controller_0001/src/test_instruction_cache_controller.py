import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

import harness_library as hrs_lb

def calculate_expected_data(data_0, data_1, unaligned):

    if unaligned:
        return (data_0 << 16) | data_1
    else:
        return (data_1 << 16) | data_0


@cocotb.test()
async def test_instruction_cache_controller(dut):

    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Reset initialization
    await hrs_lb.dut_init(dut)
    await hrs_lb.reset_dut(dut.rst, duration_ns=25, active=False)
    await RisingEdge(dut.clk)
    # Simulate a memory read sequence
    for _ in range(10):
        
        dut.io_mem_ready.value = random.choice([0, 1])
        dut.l1b_addr.value = random.randint(0, 0x3FFFF)  # Random L1 cache address

        data_0 = random.randint(0, 0xFFFF)
        data_1 = random.randint(0, 0xFFFF)
        dut.ram512_d0_data.value = data_0
        dut.ram512_d1_data.value = data_1

        # Verify output signals
        unaligned = int(dut.l1b_addr.value) & 0x1
        expected_data = calculate_expected_data(data_0, data_1, unaligned)

        if dut.l1b_wait.value == 0:
            assert int(dut.l1b_data.value) == expected_data, (
                f"Mismatch in l1b_data. Expected: {expected_data:#010X}, Got: {int(dut.l1b_data.value):#010X}"
            )
        await RisingEdge(dut.clk)
    # Test corner cases
    dut._log.info("Testing corner cases...")

    corner_cases = [
        (0x00000, False),  # Minimum address (aligned)
        (0x3FFFF, True),   # Maximum address (unaligned)
        (0x123FE, False),  # Near boundary, aligned
        (0x123FF, True),   # Near boundary, unaligned
    ]

    for addr, unaligned in corner_cases:
        dut.io_mem_ready.value = random.choice([0, 1])
        dut.l1b_addr.value = addr
        data_0 = random.randint(0, 0xFFFF)
        data_1 = random.randint(0, 0xFFFF)
        dut.ram512_d0_data.value = data_0
        dut.ram512_d1_data.value = data_1

        # Verify output signals
        unaligned = dut.l1b_addr.value
        expected_data = calculate_expected_data(data_0, data_1, unaligned)

        if dut.l1b_wait.value == 0:
            assert int(dut.l1b_data.value) == expected_data, (
                f"Corner Case Mismatch for address {addr:#06X}: Expected {expected_data:#010X}, Got {int(dut.l1b_data.value):#010X}"
            )
        else:
            dut._log.info(f"Corner Case Success for address {addr:#06X}: Data is being fetched.")
        await RisingEdge(dut.clk)

    # Test random cases
    dut._log.info("Testing random cases...")
    for _ in range(20):
        addr = random.randint(0, 0x3FFFF)
        unaligned = addr & 0x1
        data_0 = random.randint(0, 0xFFFF)
        data_1 = random.randint(0, 0xFFFF)

        dut.l1b_addr.value = addr
        dut.ram512_d0_data.value = data_0
        dut.ram512_d1_data.value = data_1

        expected_data = calculate_expected_data(data_0, data_1, unaligned)

        if dut.l1b_wait.value == 0:
            assert int(dut.l1b_data.value) == expected_data, (
                f"Random Case Mismatch for address {addr:#06X}: Expected {expected_data:#010X}, Got {int(dut.l1b_data.value):#010X}"
            )
        else:
            dut._log.info(f"Random Case Success for address {addr:#06X}: Data is being fetched.")
        await RisingEdge(dut.clk)
    # End simulation with no errors
    dut._log.info("Test completed successfully.")
