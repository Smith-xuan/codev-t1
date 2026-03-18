import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_pipelined_skid_buffer(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.clock, 5, units='ns').start())
    
    await hrs_lb.dut_init(dut)

    await FallingEdge(dut.clock)
    dut.rst.value = 0
    await FallingEdge(dut.clock)
    dut.rst.value = 1
    await FallingEdge(dut.clock)
    dut.rst.value = 0

    await RisingEdge(dut.clock)
    assert dut.data_o.value == 0, f"[ERROR] data_out value is : {dut.data_o.value}"
    assert dut.valid_o.value == 0, f"[ERROR] valid_o: {dut.valid_o.value}"
    assert dut.ready_o.value == 1, f"[ERROR] done: {dut.ready_o.value}"
    print(f'reset successful ')
    
    print(f'Testing Normal operation that is without back pressure (downstream block are always ready)')

    await FallingEdge(dut.clock)
    dut.i_data.value = 1
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await FallingEdge(dut.clock)
    dut.i_data.value = 2
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 1, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 3
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 2, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 4
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 3, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 5
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 4, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 6
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 5, f"[ERROR] data_out value is : {dut.data_o.value}"
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 6, f"[ERROR] data_out value is : {dut.data_o.value}"

    
    print(f'Normal operation successfully tested')

    print(f'testing operation with back pressure from downstream blocks(down stream block are not ready always)')

    await FallingEdge(dut.clock)
    dut.i_data.value = 1
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await FallingEdge(dut.clock)
    dut.i_data.value = 2
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 1, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 3
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 2, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 4
    dut.i_valid.value = 1
    dut.ready_i.value = 0
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 2, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 5
    dut.i_valid.value = 1
    dut.ready_i.value = 0
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 2, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 6
    dut.i_valid.value = 1
    dut.ready_i.value = 0
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 2, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 7
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 3, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 8
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 4, f"[ERROR] data_out value is : {dut.data_o.value}"
    await FallingEdge(dut.clock)
    dut.i_data.value = 9
    dut.i_valid.value = 1
    dut.ready_i.value = 1
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 5, f"[ERROR] data_out value is : {dut.data_o.value}"
    await RisingEdge(dut.clock)
    await Timer(1, units="ns")
    assert dut.data_o.value == 9, f"[ERROR] data_out value is : {dut.data_o.value}"

    
    print(f'operation with back pressure from downstream blocks tested successfully')
    