import cocotb
# import uvm_pkg::*
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
# from cocotb.results import TestFailure
import random
import time
import harness_library as hrs_lb
import math

@cocotb.test()
async def test_neuromorphic_array(dut):
    """Test the neuromorphic_array with various inputs and control signals."""
    
     # Generate clock signal
    clock_period_ns = 10
    cocotb.start_soon(Clock(dut.clk, clock_period_ns, units="ns").start())

    # Initialize DUT
    await hrs_lb.dut_init(dut)
    
    # Apply reset 
    await hrs_lb.reset_dut(dut.rst_n, 2*clock_period_ns)
    # Wait for a couple of cycles to stabilize
    for i in range(2):
       await RisingEdge(dut.clk)
    # Run specific test cases
    print(f"test 0")
    await apply_test_case(dut, 0, 0x0)
    print(f"test 1")
    await apply_test_case(dut, random.randint(0, 1), 0xF1)
    print(f"test 2")
    await apply_test_case(dut,  random.randint(0, 1), 0xF)
    print(f"test 3")
    await apply_test_case(dut,  random.randint(0, 1), 0x0) 
    print(f"test 4")
    await apply_test_case(dut,  random.randint(0, 1), 0xAA)
    print(f"test 5")
    await apply_test_case(dut,  random.randint(0, 1), 0xF0)
    print(f"test 6")
    await apply_test_case(dut,  random.randint(0, 1), 0x1)
    print(f"test 7")
    await apply_test_case(dut,  random.randint(0, 1), 0x3C)
    print(f"test 8")
    await apply_test_case(dut,  random.randint(0, 1), 0x3)
    n = 0
    # Run random test cases
    for n in range(random.randint(10, 100)):
        print(f"test : {n+9}")
        control_signal = random.randint(0, 255)
        input_data = random.randint(0, 255)
        await apply_test_case(dut, control_signal, input_data)
    
    cocotb.log.info("All test cases passed.")

async def apply_test_case(dut, control_signal, input_data):
    """Applies a test case to the DUT and checks the expected output."""
    dut.ui_in.value = control_signal
    dut.uio_in.value = input_data
    
    print(f"control_signal={control_signal},input_data={input_data}")
    await FallingEdge(dut.clk)  # Wait for a clock cycle
    await FallingEdge(dut.clk)  # Wait for a clock cycle
    expected_output = input_data if (control_signal & 0x1) else dut.uo_out.value.integer
    
    print(f"expected_output={expected_output},actual_output={dut.uo_out.value.integer}")
    print(f"")
    # Assertion to check output correctness
    assert dut.uo_out.value.integer == expected_output, (
        f"Expected={expected_output:08b}, Got={int(dut.uo_out.value):08b}")
    
    print(f"Test passed! ")
