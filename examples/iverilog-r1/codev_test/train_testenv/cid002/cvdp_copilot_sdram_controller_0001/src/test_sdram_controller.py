import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_sdram_controller(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 5, units='ns').start())
    
    await hrs_lb.dut_init(dut)
    

    await FallingEdge(dut.clk)
    dut.addr.value = 0
    dut.data_in.value = 0
    dut.read.value = 0
    dut.write.value = 0
    await FallingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.reset.value = 0
    await FallingEdge(dut.clk)
    dut.reset.value = 1
    await FallingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    assert dut.sdram_cke.value == 1, f"[ERROR] sdram_cke value is : {dut.sdram_cke.value}"
    print(f'reset successful ')

    for i in range(10):
        await FallingEdge(dut.clk)
        print(f'waiting for initialization ')

    await FallingEdge(dut.clk)
    dut.addr.value = 0x00_ffff
    dut.sdram_dq.value = 0xfff0
    dut.read.value = 1
    dut.write.value = 0
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert dut.data_out.value == 0xfff0, f"[ERROR] data_out value is : {dut.data_out.value}"
    print(f'received data_out is equal to sdram_dq value {dut.data_out.value}')
    dut.read.value = 0

    print(f'read operation successful')

   


    await FallingEdge(dut.clk)
    dut.addr.value = 0x00_aaaa
    dut.data_in.value = 0xf0f0
    dut.read.value = 0
    dut.write.value = 1
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert dut.dq_out.value == 0xf0f0, f"[ERROR] dq_out value is : {dut.dq_out.value}"
    print(f'write dq_out is equal to data_in value {dut.dq_out.value}')
    dut.write.value = 0
    print(f'write operation successful')

    print(f'state value {dut.state.value}')
    
    print(f'testing for auto refresh function')
    for i in range(1024):
        await FallingEdge(dut.clk)
        #print(f'state value {dut.refresh_counter.value}')
    await FallingEdge(dut.clk)
    assert dut.sdram_cke.value == 1, f"[ERROR] sdram_cke value is : {dut.sdram_cke.value}"
    assert dut.sdram_cs.value == 1, f"[ERROR] sdram_cs value is : {dut.sdram_cs.value}"
    assert dut.sdram_ras.value == 1, f"[ERROR] sdram_ras value is : {dut.sdram_ras.value}"
    assert dut.sdram_cas.value == 1, f"[ERROR] sdram_cas value is : {dut.sdram_cas.value}"

    print(f'testing for auto refresh function successful')
   


    
    print(f' tested successfully')
    