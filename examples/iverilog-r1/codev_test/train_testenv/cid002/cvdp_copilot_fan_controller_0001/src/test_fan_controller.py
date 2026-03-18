import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_fan_controller(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 5, units='ns').start())
    
    await hrs_lb.dut_init(dut)
    
    
    await FallingEdge(dut.clk)
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0
    dut.paddr.value = 0
    dut.pwdata.value = 0
    await FallingEdge(dut.clk)


    await FallingEdge(dut.clk)
    dut.reset.value = 0
    await FallingEdge(dut.clk)
    dut.reset.value = 1
    await FallingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)
    assert dut.fan_pwm_out.value == 0, f"[ERROR] fan_pwm_out value is : {dut.fan_pwm_out.value}"
    print(f'reset successful ')
    


    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 0
    dut.pwrite.value = 1
    dut.paddr.value = 0x0a
    dut.pwdata.value = 31
    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 1
    dut.pwrite.value = 1
    dut.paddr.value = 0x0a
    dut.pwdata.value = 31
    await FallingEdge(dut.clk)
    assert dut.pready.value == 1, f"[ERROR] pready value is not 1 : {dut.pready.value}"
    await FallingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 0
    dut.pwrite.value = 1
    dut.paddr.value = 0x0b
    dut.pwdata.value = 61
    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 1
    dut.pwrite.value = 1
    dut.paddr.value = 0x0b
    dut.pwdata.value = 61
    await FallingEdge(dut.clk)
    assert dut.pready.value == 1, f"[ERROR] pready value is not 1 : {dut.pready.value}"
    await FallingEdge(dut.clk)


    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 0
    dut.pwrite.value = 1
    dut.paddr.value = 0x0c
    dut.pwdata.value = 91
    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 1
    dut.pwrite.value = 1
    dut.paddr.value = 0x0c
    dut.pwdata.value = 91
    await FallingEdge(dut.clk)
    assert dut.pready.value == 1, f"[ERROR] pready value is not 1 : {dut.pready.value}"
    await FallingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 0
    dut.pwrite.value = 1
    dut.paddr.value = 0x0f
    dut.pwdata.value = 75
    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 1
    dut.pwrite.value = 1
    dut.paddr.value = 0x0f
    dut.pwdata.value = 75
    await FallingEdge(dut.clk)
    assert dut.pready.value == 1, f"[ERROR] pready value is not 1 : {dut.pready.value}"
    await FallingEdge(dut.clk)
    

    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 0
    dut.pwrite.value = 0
    dut.paddr.value = 0x0f
    dut.pwdata.value = 75
    await FallingEdge(dut.clk)
    dut.psel.value = 1
    dut.penable.value = 1
    dut.pwrite.value = 0
    dut.paddr.value = 0x0f
    dut.pwdata.value = 75
    await FallingEdge(dut.clk)
    assert dut.pready.value == 1, f"[ERROR] pready value is not 1 : {dut.pready.value}"
    assert dut.prdata.value == 75, f"[ERROR] prdata value is not matching : {dut.prdata.value}"
    print(f'read for temp sensor :  {dut.prdata.value} ')
    await FallingEdge(dut.clk)


    for i in range(255):
        await FallingEdge(dut.clk)
        if(dut.pwm_counter.value.integer <= 192 and dut.pwm_counter.value.integer != 0):
         print(f'waiting for initialization {dut.fan_pwm_out.value.integer,dut.pwm_counter.value.integer}')
         assert dut.fan_pwm_out.value == 1, f"[ERROR] prdata value is not matching : {dut.fan_pwm_out.value.integer,dut.pwm_counter.value.integer}"
        else:
         print(f'waiting for initialization {dut.fan_pwm_out.value.integer,dut.pwm_counter.value.integer}')
         assert dut.fan_pwm_out.value == 0, f"[ERROR] prdata value is not matching : {dut.fan_pwm_out.value.integer,dut.pwm_counter.value.integer}"
        
    



    
    print(f' tested successfully')
    