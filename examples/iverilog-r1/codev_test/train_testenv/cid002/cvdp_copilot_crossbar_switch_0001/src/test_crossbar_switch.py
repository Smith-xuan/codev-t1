import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb



@cocotb.test()
async def test_crossbar_switch(dut): 
    # Start clock
    clock_period_ns = 10
    cocotb.start_soon(Clock(dut.clk, clock_period_ns, units='ns').start())
    print("[INFO] Clock started.")
    
    # Initialize DUT
    await hrs_lb.dut_init(dut)
    
    # Apply reset 
    await hrs_lb.reset_dut(dut.reset, clock_period_ns)
    
    # Wait for a couple of cycles to stabilize
    for i in range(2):
       await RisingEdge(dut.clk)
       
    # Ensure all outputs are zero
    assert dut.out0.value == 0, f"[ERROR] out0 is not zero after reset: {dut.out0.value}"
    assert dut.out1.value == 0, f"[ERROR] out1 is not zero after reset: {dut.out1.value}"
    assert dut.out2.value == 0, f"[ERROR] out2 is not zero after reset: {dut.out2.value}"
    assert dut.out3.value == 0, f"[ERROR] out3 is not zero after reset: {dut.out3.value}"
    assert dut.valid_out0.value == 0, f"[ERROR] valid_out0 is not zero after reset: {dut.valid_out0.value}"
    assert dut.valid_out1.value == 0, f"[ERROR] valid_out1 is not zero after reset: {dut.valid_out1.value}"
    assert dut.valid_out2.value == 0, f"[ERROR] valid_out2 is not zero after reset: {dut.valid_out2.value}"
    assert dut.valid_out3.value == 0, f"[ERROR] valid_out3 is not zero after reset: {dut.valid_out3.value}"
   
   
    # Get parameter values from top module
    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    MAX_VALUE = (1 << DATA_WIDTH) - 1  # Maximum 32-bit value (0xFFFFFFFF)
    NUM_PORTS = int(dut.NUM_PORTS.value)
    print(f"DATA_WIDTH = {DATA_WIDTH}")
    print(f"NUM_PORTS = {NUM_PORTS}")

    # Define the outputs and assign them to a list for easy manipulation
    outputs = [dut.out0, dut.out1, dut.out2, dut.out3]
    # Define the outputs valids and assign them to a list for easy manipulation
   #  output_valid = [dut.valid_out0.value.integer, dut.valid_out1.value.integer, dut.valid_out2.value.integer, dut.valid_out3.value.integer]
    output_valid_dut = [dut.valid_out0, dut.valid_out1, dut.valid_out2, dut.valid_out3]
    # Define the inputs and assign them to a list for easy manipulation
    inputs = [dut.in0, dut.in1, dut.in2, dut.in3]
    # Define the input valids and assign them to a list for easy manipulation
    input_valid = [dut.valid_in0, dut.valid_in1, dut.valid_in2, dut.valid_in3]
    
    # Generating random number of cycles
    MIN_CYCLES = 10
    cycle_num =  random.randint(MIN_CYCLES, 100)
    
    # Apply random stimulus and check output
    for cycle in range(cycle_num):  # Run the test for random number of cycles
       
         dut.valid_in0.value = 0  # default value to zero
         dut.valid_in1.value = 0  # default value to zero
         dut.valid_in2.value = 0  # default value to zero
         dut.valid_in3.value = 0  # default value to zero
         input_port_list = [0, 0, 0, 0]
         input_port_valids = [0, 0, 0, 0]
       
         # Shuffle the sequence of inputs
         dest_id = random.randint(0, NUM_PORTS-1)
         values = random.randint(0, MAX_VALUE)
         concatenated_value =  ((dest_id << DATA_WIDTH ) | (values & MAX_VALUE)) # Concatination and Ensuring value is within N-bit range
         input_port = random.choice(inputs) # Randomly select an input port
         if random.choice([True, False]): # Randomly execute this statement in one of the iterations
            dest_id_2 = random.randint(0, NUM_PORTS-1)
            
            values_2 = random.randint(0, MAX_VALUE)
            concatenated_value_2 =  ((dest_id_2 << DATA_WIDTH ) | (values_2 & MAX_VALUE)) # Concatination and Ensuring value is within N-bit range
            input_port_2 = random.choice(inputs) # Randomly select an input port
            while input_port_2 == input_port:
               input_port_2 = random.choice(inputs)
            index_of_input_port_2 = inputs.index(input_port_2) # Find the index of the randomly selected input_port
            
            input_port_2.value = concatenated_value_2
            input_valid[index_of_input_port_2].value = 1  # Ensure value is within 32-bit range
            print(f"Assigned value {hex(concatenated_value_2)} to in{index_of_input_port_2} with dest id = {dest_id_2}")
            input_port_list[index_of_input_port_2] = concatenated_value_2
            input_port_valids[index_of_input_port_2] = 1
            
            
         index_of_input_port = inputs.index(input_port) # Find the index of the randomly selected input_port
         
         input_port.value = concatenated_value
         # dut.in0.value = concatenated_value
         input_valid[index_of_input_port].value = 1  # Ensure value is within 32-bit range
         print(f"Assigned value {hex(concatenated_value)} to in{index_of_input_port} with dest id = {dest_id}")

         await RisingEdge(dut.clk)
         await RisingEdge(dut.clk)
         
         # Read the actual results 
         output_valid = [output_valid_dut[0].value.integer ,output_valid_dut[1].value.integer ,output_valid_dut[2].value.integer ,output_valid_dut[3].value.integer ]
         print(output_valid)
         index_of_actual_output_valid = output_valid.index(1)
         actual_output = outputs[index_of_actual_output_valid].value.integer
         actual_output_valid = output_valid[index_of_actual_output_valid]
         print(f"[DEBUG] Cycle {cycle+1}/{cycle_num} Actual  : out{index_of_actual_output_valid}   = {hex(actual_output)}, valid_out{index_of_actual_output_valid}   = {actual_output_valid}")
         # Read the expected results
         
         input_port_list[index_of_input_port] = concatenated_value
         input_port_valids[index_of_input_port] = 1
         
         # print(f"input_port_list {input_port_list}, input_port_valids{input_port_valids}")
         
         
         output_ports , output_valids, expected_dest_id = await hrs_lb.crossbar_switch_4x4 (input_port_list, input_port_valids,DATA_WIDTH)
         expected_output = output_ports[expected_dest_id]
         expected_output_valid = output_valids[expected_dest_id]
         print(f"[DEBUG] Cycle {cycle+1}/{cycle_num} Expected: out{expected_dest_id}   = {hex(expected_output)}, valid_out{expected_dest_id}   = {expected_output_valid}")
         
         
         # Compare expected result with actual results and add assertions
         if actual_output_valid == 1 and expected_output_valid == 1:
             # Ensure the actual output data matches the expected output data
             assert actual_output == expected_output, f"[ERROR] Expected result: {hex(expected_output)}, but got {hex(actual_output)} at cycle {cycle} when valid_out = 1"
         
             # Check that all other output valid signals are low, and their corresponding output data is 0 or invalid
             for i in range(NUM_PORTS):
                 if i != index_of_actual_output_valid:  # Skip the expected valid output
                     assert output_valid[i] == 0, f"[ERROR] valid_out{i} is high, but expected to be low at cycle {cycle}"
                     assert outputs[i].value == 0, f"[ERROR] out{i} is {hex(outputs[i].value)}, but expected to be 0 at cycle {cycle}"
         
             print(f"[PASS] Cycle {cycle+1}: Expected result matches actual output, and all other outputs are low.")
         else:
            print(f"[DEBUG] Skipping result check at cycle {cycle+1} because valid_out is not 1.")

         print(f"\n")
         await RisingEdge(dut.clk)
         await RisingEdge(dut.clk)
         



print("[INFO] Test 'test_crossbar_switch' completed successfully.")
