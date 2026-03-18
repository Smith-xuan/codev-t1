import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge,ReadOnly, FallingEdge, Timer
import random
import time
import harness_library as hrs_lb
import math

# Master Function
async def master(dut, addr, data, write=True):
    """Mimic the AXI master to perform read or write  transactions."""
    if write:
        # Perform a write transaction
        dut.inport_awaddr_i.value = addr
        dut.inport_awvalid_i.value = 1
        await RisingEdge(dut.clk_i)
        actual_master_awaddr = dut.inport_awaddr_i.value.integer
        actual_master_awvalid = dut.inport_awvalid_i.value.integer
        if addr >= 0x80000000 :
            expected_awvalid =  dut.outport_peripheral0_awvalid_o.value.integer
            expected_awaddr = dut.outport_peripheral0_awaddr_o.value.integer
            print(f"[DEBUG] Salve=Peripheral0")
        else :
            expected_awvalid = dut.outport_awvalid_o.value.integer
            expected_awaddr = dut.outport_awaddr_o.value.integer
            print(f"[DEBUG] Salve=Default")
            
        print(f"[DEBUG] addr={addr}")
        print(f"[DEBUG] actual_master_awaddr={actual_master_awaddr},actual_master_awvalid={actual_master_awvalid}")
        print(f"[DEBUG] expected_awaddr     ={expected_awaddr},expected_awvalid     ={expected_awvalid}")
        
        assert actual_master_awvalid == expected_awvalid , f"[ERROR] Wrong awvalid!"
        assert actual_master_awaddr == expected_awaddr , f"[ERROR] Wrong awaddr!"

        
        # Write data
        dut.inport_wdata_i.value = data
        dut.inport_wvalid_i.value = 1
        dut.inport_wstrb_i.value = random.randint(0x0, 0xF)
        await RisingEdge(dut.clk_i)
        actual_master_wdata = dut.inport_wdata_i.value.integer
        actual_master_wvalid = dut.inport_wvalid_i.value.integer
        actual_master_wstrb = dut.inport_wstrb_i.value.integer
        if addr >= 0x80000000 :
            expected_wvalid =  dut.outport_peripheral0_wvalid_o.value.integer
            expected_wdata = dut.outport_peripheral0_wdata_o.value.integer
            expected_wstrb = dut.outport_peripheral0_wstrb_o.value.integer
        else :
            expected_wvalid =  dut.outport_wvalid_o.value.integer
            expected_wdata = dut.outport_wdata_o.value.integer
            expected_wstrb = dut.outport_wstrb_o.value.integer
        print(f"[DEBUG] actual_master_wdata={actual_master_wdata},actual_master_wvalid={actual_master_wvalid},actual_master_wstrb={actual_master_wstrb}")
        print(f"[DEBUG] expected_wdata     ={expected_wdata},expected_wvalid     ={expected_wvalid},expected_wstrb=     {expected_wstrb}")
        
        assert actual_master_wdata == expected_wdata , f"[ERROR] Wrong wdata!"
        assert actual_master_wvalid == expected_wvalid , f"[ERROR] Wrong wvalid!"
        assert actual_master_wstrb == expected_wstrb , f"[ERROR] Wrong wstrb!"

        dut.inport_wdata_i.value = 0
        dut.inport_wvalid_i.value = 0
        dut.inport_wstrb_i.value = 0
        dut.inport_awaddr_i.value = 0
        dut.inport_awvalid_i.value = 0
    else:
        # read address
        dut.inport_araddr_i.value = addr
        dut.inport_arvalid_i.value = 1

        await RisingEdge(dut.clk_i)
        await RisingEdge(dut.clk_i)

        actual_read_rdata = dut.inport_rdata_o.value.integer
        actual_read_rvalid = dut.inport_rvalid_o.value.integer
        actual_read_rresp = dut.inport_rresp_o.value.integer
        
        if addr >= 0x80000000 :
            expected_read_rdata =  dut.outport_peripheral0_rdata_i.value.integer
            expected_read_rvalid = dut.outport_peripheral0_rvalid_i.value.integer
            expected_read_rresp = dut.outport_peripheral0_rresp_i.value.integer
            print(f"[DEBUG] Salve=Peripheral0")
        else :
            expected_read_rdata =  dut.outport_rdata_i.value.integer
            expected_read_rvalid = dut.outport_rvalid_i.value.integer
            expected_read_rresp = dut.outport_rresp_i.value.integer
            print(f"[DEBUG] Salve=Default")
            
        print(f"[DEBUG] addr={addr}")
        print(f"[DEBUG] actual_read_rdata   ={hex(actual_read_rdata)},actual_read_rvalid={actual_read_rvalid},actual_read_rresp={actual_read_rresp}")
        print(f"[DEBUG] expected_read_rdata ={hex(expected_read_rdata)},expected_read_rvalid  ={expected_read_rvalid},expected_read_rresp= {expected_read_rresp}")
        
        assert actual_read_rdata == expected_read_rdata , f"[ERROR] Wrong rdata!"
        assert actual_read_rvalid == expected_read_rvalid , f"[ERROR] Wrong rvalid!"
        assert actual_read_rresp == expected_read_rresp , f"[ERROR] Wrong rresp!"



@cocotb.test()
async def test_axi_tap(dut):
    """Test the AXI Tap module."""

    # Start clock
    clock_period_ns = 10  # For example, 10ns clock period
    cocotb.start_soon(Clock(dut.clk_i, clock_period_ns, units="ns").start())
    # Initialize DUT
    await hrs_lb.dut_init(dut)
    # Apply reset 
    await hrs_lb.reset_dut(dut.rst_i, 50)
    
    # Extracting parameters
    ADDR_WIDTH = int(dut.ADDR_WIDTH.value)
    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    print(f"ADDR_WIDTH = {ADDR_WIDTH},DATA_WIDTH = {DATA_WIDTH}")
    MAX_ADDR_WIDTH = (1 << ADDR_WIDTH) - 1
    MAX_DATA_WIDTH = (1 << DATA_WIDTH) - 1
    print(f"MAX_ADDR_WIDTH = {hex(MAX_ADDR_WIDTH)},MAX_DATA_WIDTH = {hex(MAX_DATA_WIDTH)}")
    
    
    
    # Making all devices ready to accept data
    dut.inport_bready_i.value = 1
    dut.inport_rready_i.value = 1
    dut.outport_awready_i.value = 1
    dut.outport_wready_i.value = 1
    dut.outport_arready_i.value = 1
    dut.outport_peripheral0_awready_i.value = 1
    dut.outport_peripheral0_wready_i.value = 1
    dut.outport_peripheral0_arready_i.value = 1
    
    # Assigning response channel of slaves
    dut.outport_peripheral0_rvalid_i.value = 1
    dut.outport_peripheral0_rdata_i.value = 0xBEEFFEED & MAX_DATA_WIDTH
    dut.outport_peripheral0_rresp_i.value = random.randint(0x0, 0x3)
    dut.outport_rvalid_i.value = 1
    dut.outport_rdata_i.value = 0xDEADBEEF & MAX_DATA_WIDTH
    dut.outport_rresp_i.value = random.randint(0x0, 0x3)
    # await RisingEdge(dut.clk_i)
    
    # Generate random address
    addr = random.randint(0x00000000, MAX_ADDR_WIDTH)
    if random.random() > 0.5:  # 50% chance
        addr = random.randint(0x80000001, MAX_ADDR_WIDTH)
    # Generate random data
    data = random.randint(0x00000000, MAX_DATA_WIDTH)
    # Generate random write
    write = random.choice([True, False])

    await RisingEdge(dut.clk_i)
    
    # Call the master function with the specified parameters
    await master(dut, addr, data, write)
    
    dut.inport_arvalid_i.value = 0
    dut.outport_peripheral0_rvalid_i.value = 0
    dut.outport_peripheral0_rdata_i.value = 0
    dut.outport_peripheral0_rresp_i.value = 0
    dut.outport_rvalid_i.value = 0
    dut.outport_rdata_i.value = 0
    dut.outport_rresp_i.value = 0

    for i in range(20):
       await RisingEdge(dut.clk_i)

    print("Test completed.")
