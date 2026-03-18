import cocotb
# import uvm_pkg::*
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
# from cocotb.results import TestFailure
import random
import time
import harness_library as hrs_lb
import math

def reverse_Bits(n, no_of_bits):
    result = 0
    for i in range(no_of_bits):
        result <<= 1
        result |= n & 1
        n >>= 1
    return result
@cocotb.test()

async def test_copilot_rs_232(dut):
    """ Test the RS232 transmitter module """
    print(f"Check 0")
    CLOCK_FREQ = dut.CLOCK_FREQ.value.integer
    print(f"Check 1")
    BAUD_RATE = dut.BAUD_RATE.value.integer
    print(f"Check 2")
    clock_period_ns = (1/CLOCK_FREQ)*10e8
    print(f"CLOCK_FREQ = {CLOCK_FREQ},clock_period_ns = {clock_period_ns}")
    print(f"BAUD_RATE = {BAUD_RATE}")
    
    # Create a clock on the clock signal
    cocotb.start_soon(Clock(dut.clock, clock_period_ns, units="ns").start())
    
    # Initialize DUT
    await hrs_lb.dut_init(dut)
    
    # Apply reset 
    await hrs_lb.reset_dut(dut.reset_neg, clock_period_ns)
    
    # Wait for a couple of cycles to stabilize
    for i in range(2):
       await RisingEdge(dut.clock)

    # Inject random test data 
    test_data = random.randint(1, 255)
    dut.tx_datain.value = test_data & 0xFF
    dut.tx_datain_ready.value = 1
    await RisingEdge(dut.clock)

    # Wait for the transmitter to start processing
    while dut.tx_transmitter_valid.value.integer == 1 :
        await RisingEdge(dut.clock)

    # Monitor the transmitted bits
    transmitted_word = 0
    transmitted_data = 0x0
    baud_interval = (1/BAUD_RATE)
    baud_interval = int(baud_interval * 1e9)
    print(f"baud_interval = {baud_interval}")
    
    for i in range(10):  # Start bit + 8 data bits + stop bit
        await RisingEdge(dut.clock)
        # await Timer(8680, units="ns")  # Wait for one baud interval (115200 baud ~ 8.68 µs)
        if i == 0 :
            await Timer(int(baud_interval/2), units="ns")  # Wait for one baud interval (115200 baud ~ 8.68 µs)
        else :    
            await Timer(baud_interval, units="ns")  # Wait for one baud interval (115200 baud ~ 8.68 µs)
        transmitted_bit = int(dut.tx_transmitter.value.integer)
        # Assuming transmitted_word is an 8-bit integer (0-255)
        transmitted_word = transmitted_word << 1  # Shift left by 1
        transmitted_word = transmitted_word & 0x3FF  # Mask to ensure it's within 8-bit range
        transmitted_word |= transmitted_bit  # Set the LSB to transmitted_bit
        transmitted_data = transmitted_word << 1
        print(f"Bit {i}: {transmitted_bit}, transmitted_word={hex(transmitted_word)},transmitted_data={hex(transmitted_data)}")
    
    transmitted_data = transmitted_word >> 1
    reverse_transmitted_data = reverse_Bits(int(transmitted_data),8)
    print(f"transmitted_data = {transmitted_data}, reverse_transmitted_data={reverse_transmitted_data}")
    assert reverse_transmitted_data == test_data, f"[ERROR] Wrong transmitted_data!"
    
    for i in range(100):
       await RisingEdge(dut.clock)

    print("Transmission completed")
