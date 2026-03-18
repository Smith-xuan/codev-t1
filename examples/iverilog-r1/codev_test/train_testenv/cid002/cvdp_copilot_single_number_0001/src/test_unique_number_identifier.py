import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def reset_dut(dut):
    """Reset the DUT"""
    dut.i_rst_n.value =0
    dut.i_ready.value =0
    dut.i_number.value =0

    await FallingEdge(dut.i_clk)
    dut.i_rst_n.value = 1
    await RisingEdge(dut.i_clk)


@cocotb.test()
async def test_unique_number_identifier(dut):  # dut will be the object for RTL top.
   

    cocotb.start_soon(Clock(dut.i_clk, 10, units='ns').start())  # timeperiod= 10ns
    # Reset the DUT
    await reset_dut(dut)

    
    await RisingEdge(dut.i_clk)
    dut.i_number.value = 1
    await FallingEdge(dut.i_clk)
    dut.i_ready.value = 1
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 2
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 3
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 3
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 4
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 2
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 1
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 5
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 4
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 5
    await FallingEdge(dut.i_clk)
    dut.i_number.value = 6
    await FallingEdge(dut.i_clk)
    assert dut.o_unique_number.value==6, f"output should not be {dut.o_unique_number.value}"

