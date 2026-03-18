import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_axis_downsizer(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 100, units='ns').start())
    
    
    # Initialize DUT
    print(f'm_data before initialization = {dut.m_data.value}') ####need to remove
    await hrs_lb.dut_init(dut) 
    print(f'm_data after initialization   = {dut.m_data.value}') ####need to remove
    # Apply reset 
    await hrs_lb.reset_dut(dut.resetn, dut)
    assert dut.m_valid.value == 0, f"[ERROR] m_valid : {dut.m_valid.value}"
    assert dut.m_valid.value == 00000000000000000000000000000000, f"[ERROR] m_valid : {dut.m_valid.value}"
    assert dut.s_ready.value == 1, f"[ERROR] s_ready : {dut.s_ready.value}"

    print(f'reset succesfull') 
    

    await FallingEdge(dut.clk)
    s_data = 0b1111111011011111
    s_valid = 1
    dut.s_data.value = s_data
    dut.s_valid.value = s_valid
    await FallingEdge(dut.clk)
    #await RisingEdge(dut.m_valid)
    temp1=dut.m_data.value
    dut.m_ready.value = 1
    await FallingEdge(dut.clk)
    #await RisingEdge(dut.m_valid)
    temp2=dut.m_data.value
    dut.m_ready.value = 1
    if(temp1 == dut.s_data.value[15:8] and temp2 == dut.s_data.value[7:0]):
     print(f'Testing completed successfully')
     print(f'slave data = {dut.s_data.value} and received master data are {temp2} and {temp1}') ####need to remove 
    else:
     print(f'Testing completed unsuccessful') 
     print(f'slave data = {dut.s_data.value[15:8]} and received master data are {temp2} and {temp1}') ####need to remove 
     assert  dut.m_data.value[15:8] == temp2, f"[ERROR] m_data is not matching to s_data : {dut.m_data.value}"
     assert  dut.m_data.value[7:0] == temp1, f"[ERROR] m_data is not matching to s_data : {dut.m_data.value}"
    await FallingEdge(dut.clk)



    await FallingEdge(dut.clk)
    s_data = 0b1111000011111111
    s_valid = 1
    dut.s_data.value = s_data
    dut.s_valid.value = s_valid
    await FallingEdge(dut.clk)
    #await RisingEdge(dut.m_valid)
    temp1=dut.m_data.value
    dut.m_ready.value = 1
    await FallingEdge(dut.clk)
    #await RisingEdge(dut.m_valid)
    temp2=dut.m_data.value
    dut.m_ready.value = 1
    if(temp1 == dut.s_data.value[15:8] and temp2 == dut.s_data.value[7:0]):
     print(f'Testing completed successfully')
     print(f'slave data = {dut.s_data.value} and received master data are {temp2} and {temp1}') ####need to remove 
    else:
     print(f'Testing completed unsuccessful') 
     print(f'slave data = {dut.s_data.value[15:8]} and received master data are {temp2} and {temp1}') ####need to remove
     assert  dut.m_data.value[15:8] == temp1, f"[ERROR] m_data is not matching to s_data : {dut.m_data.value}"
     assert  dut.m_data.value[7:0] == temp2, f"[ERROR] m_data is not matching to s_data : {dut.m_data.value}"
    await FallingEdge(dut.clk)
     
    

    