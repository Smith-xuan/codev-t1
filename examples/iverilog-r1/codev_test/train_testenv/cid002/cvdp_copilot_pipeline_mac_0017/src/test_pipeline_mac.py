import cocotb
# import uvm_pkg::*
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
# from cocotb.results import TestFailure
import random
import time
import harness_library as hrs_lb
import math

def clog2(N):
    return math.ceil(math.log2(N))

@cocotb.test()
async def test_pipeline_mac(dut): 
    # Start clock
    clock_period_ns = 10  # For example, 10ns clock period
    cocotb.start_soon(Clock(dut.clk, clock_period_ns, units='ns').start())
    print("[INFO] Clock started.")
    
    # Get parameter values from top module
    dwidth = int(dut.DWIDTH.value)
    DWIDTH_ACCUMULATOR = int(dut.DWIDTH_ACCUMULATOR.value)
    N = int(dut.N.value)
    print(f"DWIDTH = {dwidth}, DWIDTH_ACCUMULATOR = {DWIDTH_ACCUMULATOR}, N = {N}")
    
    # Initialize DUT
    await hrs_lb.dut_init(dut)
    
    # Apply reset 
    await hrs_lb.reset_dut(dut.rstn, clock_period_ns)
    
    # Wait for a couple of cycles to stabilize
    for i in range(2):
       await RisingEdge(dut.clk)
       
    # Ensure all outputs are zero
    assert dut.result.value == 0, f"[ERROR] data_out is not zero after reset: {dut.result.value}"
    
    # Generating random number of cycles
    MIN_CYCLES = 2*N
    
    # MIN_CYCLES = 16
    cycle_num =  random.randint(MIN_CYCLES, 4*MIN_CYCLES)
    
    # Generating random values for multiplicand and multiplier
    MAX_VALUE = (1 << dwidth) - 1  # Maximum dwidth-bit value (0xFFFFFFFF)
    random_multiplicand = [random.randint(1, MAX_VALUE) for _ in range(cycle_num)]
    random_multiplier = [random.randint(1, MAX_VALUE) for _ in range(cycle_num)]
    N_cycles = 0
    Dessert_valid_in = 0
    apply_reset = 0
    random_reset_cycle = 0
    
    if random.choice([True, False]):
       Dessert_valid_in = 1
       N_cycles = random.randint(1, 3)
       
    if random.choice([True, False]): # Randomly execute this statement in one of the iterations
      random_multiplicand = [ MAX_VALUE for _ in range(cycle_num)]
      random_multiplier = [MAX_VALUE for _ in range(cycle_num)]
    
    if random.choice([True, False]): # Randomly apply reset.
       apply_reset = 1
       random_reset_cycle = random.randint(N, cycle_num - N) 
    
    # Initizaling local variables 
    expected_result_temp = 0
    expected_result = 0
    expected_valid_out = 0
    counter = 0
    expected_accumulator = 0
    valid_in = 1
    accumulator = 0
    multiplication = 0
    expected_result_s1 = 0
    expected_result_s2 = 0
    expected_result_s3 = 0
    expected_valid_out_s1 = 0
    expected_valid_out_s2 = 0
    expected_valid_out_s3 = 0
    valid_down_counter = 0
    first_iteration = 1
    Cuurent_valid_out_cycle_num = 0
    last_valid_out_cycle_num =0 
    random_cycle = 0
    reset_applied = 0
    reset_cycle_num = 0
    reset_factor = 0
    
    # Apply random stimulus and check output
    for cycle in range(cycle_num):  # Run the test for random number of cycles
       
         if apply_reset == 1 and reset_applied == 0 and cycle == random_reset_cycle:
            # Initialize DUT
            await hrs_lb.dut_init(dut)
            # Apply reset
            await hrs_lb.reset_dut(dut.rstn, clock_period_ns)
             # Wait for a couple of cycles to stabilize
            for i in range(2):
               await RisingEdge(dut.clk)
            reset_applied = 1
            counter = 0 
            multiplication = 0
            expected_result = 0
            expected_result_s1 = 0
            expected_result_s2 = 0
            expected_result_s3 = 0
            expected_result_s4 = 0
            expected_valid_out = 0
            expected_valid_out_s1 = 0
            expected_valid_out_s2 = 0
            expected_valid_out_s3 = 0
            expected_valid_out_s4 = 0
            actual_valid_out = 0
            actual_result = 0
            first_iteration = 1
            reset_cycle_num = (cycle)
            Cuurent_valid_out_cycle_num = 0
            valid_down_counter = 0
            reset_factor = cycle - last_valid_out_cycle_num
            print(f"Reset Applied!")
            
         # Deaasert Valid-N for N cycles 
         valid_in = 1
         if Dessert_valid_in == 1 and first_iteration == 0:
            start_cycle = int (2*N) + int(N/2) + random_cycle
            #valid in 0 for N cycles after start_cycle 
            if cycle >= start_cycle and cycle < start_cycle + N_cycles  :
               valid_in = 0
               valid_down_counter += 1
               print(f"Valid in Deasserted for {N_cycles} cycles!")
         
         dut.multiplicand.value = random_multiplicand[cycle]
         dut.multiplier.value = random_multiplier[cycle]
         dut.valid_i.value = valid_in
         
         ###Expected output calculations
         expected_valid_out = 0
         if expected_valid_out_s1 == 1 :
            expected_result = 0
         if valid_in == 1 : 
               counter = counter + 1
               multiplication = random_multiplicand[cycle] * random_multiplier[cycle]
               expected_result += multiplication
         
         if counter == (N):
            counter = 0
            expected_valid_out = 1
            
         expected_result_s2 = expected_result_s1
         expected_valid_out_s2 = expected_valid_out_s1
         expected_result_s4 = expected_result_s3
         expected_valid_out_s4 = expected_valid_out_s3
         await RisingEdge(dut.clk)
         expected_result_s1 = expected_result
         expected_valid_out_s1 = expected_valid_out
         expected_result_s3 = expected_result_s2
         expected_valid_out_s3 = expected_valid_out_s2
         
         # Calculate the expected result to check for overflow
         DWIDTH_ACCUMULATOR_EXPECTED = clog2(N) + (2 * dwidth)
         # Read the actual results
         actual_result = dut.result.value.integer
         actual_valid_out = dut.valid_out.value.integer
         
         ## Assertion for Dwidth calculation
         assert DWIDTH_ACCUMULATOR == DWIDTH_ACCUMULATOR_EXPECTED, f"[ERROR] Expected DWIDTH_ACCUMULATOR: {DWIDTH_ACCUMULATOR_EXPECTED}, but got {DWIDTH_ACCUMULATOR} at cycle {cycle} when valid_out = 1"
         ## Check first valid out is after N+2 cycles
         if first_iteration == 1 and actual_valid_out == 1:
            first_iteration = 0
            last_valid_out_cycle_num = (cycle+1)
            assert N + 2 + reset_cycle_num == (cycle+1) , f"[ERROR] First valid out assertion is not after N+1 cycles"
            # if reset_applied == 1:
            reset_factor = 0
         ## Check valid out after first cycle is after N cycles
         elif first_iteration == 0 and actual_valid_out == 1:
            Cuurent_valid_out_cycle_num = (cycle+1)
            temp = Cuurent_valid_out_cycle_num - last_valid_out_cycle_num
            last_valid_out_cycle_num = Cuurent_valid_out_cycle_num 
            assert N + valid_down_counter  == temp , f"[ERROR] Valid out assertion after 1st iteratin is not valid at cycle, temp : {temp}"
            valid_down_counter = 0
            
         ## Assertion to compare actual and expected results
         print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: N = {cycle + 1 - last_valid_out_cycle_num - reset_factor}/{N}")
         print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: valid_in {valid_in}")
         print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: random_multiplicand = {hex(random_multiplicand[cycle])}, random_multiplier = {hex(random_multiplier[cycle])}")
         print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: Expected result = {hex(expected_result_s4)}, Expected valid_out = {expected_valid_out_s4}")
         print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: Actual result   = {hex(actual_result)}, Actual valid_out   = {actual_valid_out}")
         print(f"\n")
         assert actual_valid_out == expected_valid_out_s4, f"[ERROR] Wrong assertion of valid out signal at cycle {cycle}"
         if actual_valid_out == expected_valid_out_s4 == 1:
            assert actual_result == expected_result_s4, f"[ERROR] Expected result: {expected_result}, but got {expected_result_s4} at cycle {cycle} when valid_out = 1"

print("[INFO] Test 'test_pipeline_mac' completed successfully.")
