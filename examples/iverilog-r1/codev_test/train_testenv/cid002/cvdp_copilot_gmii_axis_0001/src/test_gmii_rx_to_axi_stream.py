import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_gmii_rx_to_axi_stream(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.gmii_rx_clk, 100, units='ns').start())
    
    
    # Initialize DUT
    #print(f'data_in before initialization = {dut.data_in.value}') ####need to remove
    await hrs_lb.dut_init(dut) 
    for i in range(10):
        await FallingEdge(dut.gmii_rx_clk)
        data_in = random.randint(0, 255)
        dut.gmii_rxd.value = i
        dut.gmii_rx_dv.value = 1
        await RisingEdge(dut.gmii_rx_clk)
        await Timer(10, units="ns")
        if (dut.m_axis_tvalid.value == 1):
            print(f'gmmii rx data is   = {bin(i)}') 
            if (dut.m_axis_tdata.value == i):
                print(f'axi output data is  = {dut.m_axis_tdata.value}')
                assert dut.m_axis_tdata.value == i, f"[ERROR] data_out is not equal to gmii input data: {dut.m_axis_tdata.value}"
