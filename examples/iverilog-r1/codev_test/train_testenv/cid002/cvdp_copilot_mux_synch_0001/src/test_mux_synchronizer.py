import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_mux_synchronizer(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.dst_clk, 100, units='ns').start())
    cocotb.start_soon(Clock(dut.src_clk, 25, units='ns').start())
    
    # Initialize DUT
    print(f'data_out before initialization = {dut.data_out.value}') ####need to remove
    await hrs_lb.dut_init(dut) 
    print(f'data_out after initialization   = {dut.data_out.value}') ####need to remove
    # Apply reset 
    await hrs_lb.reset_dut(dut.nrst, dut)
    print(f'data_out after reset  = {dut.data_out.value}') ####need to remove
    

    await FallingEdge(dut.dst_clk)
    # Ensure all outputs are zero
    assert dut.data_out.value == 0, f"[ERROR] data_out is not zero after reset: {dut.data_out.value}"

    
    for cycle in range(1):  # Run the test for random number of cycles
        # Generate random data input
        data_in = 4 #random.randint(1, 2**width-1)  # Assuming 12-bit width data
        dut.data_in.value = data_in
        dut.req.value = 1
        for j in range(3):
            await RisingEdge(dut.dst_clk)
        print(f'data_out after req =1, and 3 dst_clk clock = {dut.data_out.value}') ####need to remove
        await FallingEdge(dut.dst_clk)
        print(f'data_out after one more negedge of dst_clk  = {dut.data_out.value}') ####need to remove
        assert dut.data_out.value == data_in, f"[ERROR] data_out output is not matching to input after 3 clock cycle: {dut.ack_out.value}"
        
    for i in range(2):
        await RisingEdge(dut.dst_clk) 
    print("[INFO] Test 'test_mux_synchronizer' completed successfully.")
