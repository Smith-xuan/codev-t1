import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_dbi_decoder(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 100, units='ns').start())
    
    
    # Initialize DUT
    #print(f'data_in before initialization = {dut.data_in.value}') ####need to remove
    await hrs_lb.dut_init(dut) 
    data_in = 0 
    dut.data_in.value = data_in
    await FallingEdge(dut.clk)
    #print(f'data_in after initialization   = {dut.data_in.value}') ####need to remove
    # Apply reset 
    await hrs_lb.reset_dut(dut.rst_n, dut)
    print(f'data_out after reset  = {dut.data_out.value}') ####need to remove


    await FallingEdge(dut.clk)
    
    
    #print(f'prev data_out after first data  = {(prev_dat1),(prev_dat0)}')
    data_in = 0xaa_aaaf_ffff
    dbi_cntrl = 0b10
    dut.dbi_cntrl.value = dbi_cntrl
    dut.data_in.value = data_in
    start = 20
    end = 39
    data_in1 = (data_in >> start) & ((1 << (end - start + 1)) - 1)
    
    start = 0
    end = 19
    data_in0 = (data_in >> start) & ((1 << (end - start + 1)) - 1)
    print(f'data_in after first data  = {bin(data_in1),bin(data_in0)}')
    

    cntr11 = (dbi_cntrl >> 1) & (1 << 0)
    cntr10 = (dbi_cntrl >> 0) & (1 << 0)
    print(f'data_out after reset  = {cntr11,cntr10}') ####need to remove


    if cntr11 == 1:  # If the value is greater than 10 
        out_data1 = ~data_in1
    else:
        cntr11 == 0
        out_data1 = data_in1

    if cntr10 == 1:  # If the value is greater than 10 
        out_data0 = ~data_in0
    else:
        cntr10 == 0
        out_data0 = data_in0



    exp_out_data1 = bin(out_data1)[-20:]
    exp_out_data0 = bin(out_data0)[-20:]


    print(f'expected outdata = {exp_out_data1,exp_out_data0}')
    
    await FallingEdge(dut.clk)
    ##data_out = dut.data_out.value
    pres_dat1 = dut.data_out.value[39:20].binstr
    pres_dat0 = dut.data_out.value[19:0].binstr
    print(f'dut  outdata = {pres_dat1,pres_dat0}')
    print(f'expected  outdata = {exp_out_data1,exp_out_data0}')

    if pres_dat1 == exp_out_data1 and pres_dat0 == exp_out_data0 :  # If the value is greater than 10 
         print("[INFO] Test 'test_dbi_encoder' completed successfully.")
    else:
        print("[INFO] Test 'test_dbi_encoder' failed.")
    