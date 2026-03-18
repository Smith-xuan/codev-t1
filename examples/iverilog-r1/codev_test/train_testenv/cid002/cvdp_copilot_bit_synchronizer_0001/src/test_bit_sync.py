import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import harness_library as hrs_lb

async def bclk_domain_checker(dut, fifo):
    while True:
        await RisingEdge(dut.bclk)
        out_fifo = fifo.write(dut.adata.value)
        #cocotb.log.info(f'Model = {out_fifo},  DUT = {dut.bq2_data.value}')
        assert dut.bq2_data.value == out_fifo

@cocotb.test()
async def test_bit_sync(dut):
    cocotb.start_soon(Clock(dut.aclk, 15, units='ns').start())
    cocotb.start_soon(Clock(dut.bclk, 7, units='ns').start())
    adata = [0]
    await hrs_lb.dut_init(dut)
    await hrs_lb.reset_dut(dut.rst_n)

    fifo = hrs_lb.FIFO(dut.STAGES.value.integer)
    fifo1 = hrs_lb.FIFO(dut.STAGES.value.integer)
    fifo.reset()
    fifo1.reset()
    cocotb.start_soon(bclk_domain_checker(dut, fifo1))
    for i in range(20):
        adata[0] = i % 2
        dut.adata.value = adata[0]        
        await RisingEdge(dut.aclk)               
        model_aq2 = fifo.write(dut.bq2_data.value)
        fifo.to_list()
        assert dut.aq2_data.value == model_aq2

    cocotb.log.info("Test Completed.")