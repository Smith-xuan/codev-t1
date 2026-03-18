import cocotb
from cocotb.triggers import Timer
import random
import harness_library as hrs_lb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge



@cocotb.test()
async def test_reed_solomon_encoder(dut):
    """Test the reed_solomon_encoder."""

    # Parameters from the DUT
    K = int(dut.K.value)
    N = int(dut.N.value)
    print(f"Running with N={N} , K={K}")

    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    clock_period_ns = random.randint(5, 50)
    cocotb.start_soon(Clock(dut.clk, clock_period_ns, units='ns').start())
    
    # Initialize DUT
    await hrs_lb.dut_init(dut)
    # Apply reset
    await hrs_lb.reset_dut(dut.reset, clock_period_ns)
    
    # Wait for a couple of clock cycles to stabilize after reset signal 
    for _ in range(2):
        await RisingEdge(dut.clk)
        
    MAX_VALUE = (1 << DATA_WIDTH) - 1  # Maximum dwidth-bit value
    cycle_num = K
    print(f"Running for {cycle_num} cycles...")
    
    
    expected_parity_1 = 0x00
    expected_parity_0 = 0x00
    expected_codeword_out = 0x00
    expected_valid_out = 0
    generator_polynomial =  0x33
    data_in_ = 0x00
    feedback = 0x00
    
    for cycle in range(cycle_num):
        enable_ = 1
        data_in_ = random.randint(1, MAX_VALUE)
        data_in_ = data_in_ & 0xFF
        valid_in_ = 1
        # print(f"enable = {enable_},data_in={data_in_},valid_in={valid_in_} ")
        print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}:")
        #Feeding values to DUT
        dut.enable.value = enable_
        dut.data_in.value = data_in_
        dut.valid_in.value = valid_in_
        print(f"dut enable = {hex(dut.enable.value.integer)},dut data_in={hex(dut.data_in.value.integer)},dut valid_in={dut.valid_in.value.integer} ")
        
        expected_codeword_out_r = hex(expected_codeword_out)
        expected_valid_out_r = hex(expected_valid_out)
        expected_parity_0_r = hex(expected_parity_0)
        expected_parity_1_r = hex(expected_parity_1)
        await RisingEdge(dut.clk)
        
        #Actual outputs from DUT
        actual_codeword_out = hex(dut.codeword_out.value.integer)
        actual_valid_out = hex(dut.valid_out.value.integer)
        actual_parity_0 = hex(dut.parity_0.value.integer)
        actual_parity_1 = hex(dut.parity_1.value.integer)
        print(f"Actual codeword_out = {actual_codeword_out},Actual valid_out={actual_valid_out},Actual parity_0={actual_parity_0},Actual parity_1={actual_parity_1} ")
        
        #Mimic function
        expected_codeword_out = data_in_
        expected_valid_out = valid_in_ and enable_
        feedback = data_in_ ^ expected_parity_1;
        expected_parity_1 = expected_parity_0 ^ (feedback * generator_polynomial);
        expected_parity_0 = feedback;
        expected_parity_1 = expected_parity_1 & 0xFF
        expected_parity_0 = expected_parity_0 & 0xFF
        
        #Expected outputs from DUT
        print(f"Expected codeword_out = {expected_codeword_out_r},Expected valid_out={expected_valid_out_r},Expected parity_0={expected_parity_0_r},Expected parity_1={expected_parity_1_r} ")
        
        assert expected_codeword_out_r==actual_codeword_out, (f"expected_codeword_out_r ({expected_codeword_out_r}) != " f"actual_codeword_out ({actual_codeword_out})")
        assert expected_valid_out_r==actual_valid_out, (f"expected_valid_out_r ({expected_valid_out_r}) != " f"actual_valid_out ({actual_valid_out})")
        assert expected_parity_0_r==actual_parity_0, (f"expected_parity_0_r ({expected_parity_0_r}) != " f"actual_parity_0 ({actual_parity_0})")
        assert expected_parity_1_r==actual_parity_1, (f"expected_parity_1_r ({expected_parity_1_r}) != " f"actual_parity_1 ({actual_parity_1})")
        
        
    for _ in range(10):
        await RisingEdge(dut.clk)      
print("[INFO] Test 'test_reed_solomon_encoder' completed successfully.")
        
        
        
        
    
