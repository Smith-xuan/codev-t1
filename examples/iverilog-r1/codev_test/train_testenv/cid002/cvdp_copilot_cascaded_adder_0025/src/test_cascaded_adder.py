import cocotb
from cocotb.triggers import  Timer, RisingEdge, ReadOnly
from cocotb.clock import Clock
import harness_library as util
import random

@cocotb.test()
async def test_cascaded_adder(dut):
    # Generate  random period clock 
    DUT_CLK = Clock(dut.clk, random.randint(2, 20), 'ns')
    await cocotb.start(DUT_CLK.start())
    dut._log.info(f"DUT_CLK STARTED")

    # DUT RESET 
    dut.rst_n.value = 1
    await Timer(5, units="ns")

    #rst assertion and test
    dut.rst_n.value = 0 
    await ReadOnly()
    # for async reset, right after reset assertion design should be held in reset
    assert dut.o_valid.value == 0, f"Valid output should be driven low"
    assert dut.o_data.value == 0 , f"Output should be driven low"  
    await Timer(30, units="ns")
    dut.rst_n.value = 1
    dut._log.info(f"DUT IS OUT OF RESET") 

    # Dut parameters
    IN_DATA_WIDTH = int(dut.IN_DATA_WIDTH.value)
    IN_DATA_NS = int(dut.IN_DATA_NS.value)
    REG = int(dut.REG.value) 
    LATENCY = 2 + bin(REG).count('1')
    
    
    # overflow TC
    stimulus= util.random_stim_generator(IN_DATA_NS, IN_DATA_WIDTH, "DIRECT_MAX")
    input_data = stimulus[0]
    golden_output = stimulus[1]
    await RisingEdge(dut.clk)
    dut.i_data.value = input_data
    dut.i_valid.value = 1  
    await RisingEdge(dut.clk)
    dut.i_valid.value = 0

    latency = 0
    while (dut.o_valid.value != 1):
        await RisingEdge(dut.clk)
        latency = latency + 1

    assert latency == LATENCY, f"Valid output should have latency of {LATENCY} clk cycles"
    assert dut.o_data.value == golden_output , f"Output doesn't match golden output: dut_output {hex(dut.o_data.value)}, Expected output {hex(golden_output)}"
    

    for i in range(50):
        stimulus= util.random_stim_generator(IN_DATA_NS, IN_DATA_WIDTH, "RANDOM")
        input_data = stimulus[0]
        golden_output = stimulus[1]
        await RisingEdge(dut.clk)
        dut.i_data.value = input_data
        dut.i_valid.value = 1  
        await RisingEdge(dut.clk)
        dut.i_valid.value = 0

        latency = 0
        while (dut.o_valid.value != 1):
            await RisingEdge(dut.clk)
            latency = latency + 1

        assert latency == LATENCY, f"Valid output should have latency of {LATENCY} clk cycles"
        assert dut.o_data.value == golden_output , f"Output doesn't match golden output: dut_output {hex(dut.o_data.value)}, Expected output {hex(golden_output)}"  



