import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge
import harness_library as hrs_lb
from cocotb.triggers import Event, Timer


@cocotb.test()
async def test_int_controller(dut):
    gen_done = Event()
    test_done = Event()
    interrupts_list = set()
    priority_list = []

    cocotb.log.info(f'Priority Map {priority_list}')
    

    # Initialize signals
    dut.rst_n.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    cocotb.start_soon(Clock(dut.pclk, 10, units='ns').start())
    cocotb.log.info('Test Started')

    # Apply reset
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    # Initialize DUT
    await hrs_lb.dut_init(dut)

    # Retrieve the parameters from the DUT    
    NUM_IRQ = int(dut.NUM_INTERRUPTS.value)
    priority_list = [i for i in range(NUM_IRQ)]

    # Start main test sequences
    t_check_int = cocotb.start_soon(hrs_lb.check_int_out(dut,interrupts_list,test_done))

    t_seq_int = cocotb.start_soon(hrs_lb.gen_sequential_int(dut, interrupts_list, NUM_IRQ))
    t_ack = cocotb.start_soon(hrs_lb.gen_ack(dut, interrupts_list, gen_done, priority_list))
    await t_seq_int
    gen_done.set()
    await t_ack

    if(NUM_IRQ > 1):
        gen_done.clear()
        t_simultaneous_int = cocotb.start_soon(hrs_lb.gen_simultaneous_int(dut, interrupts_list, NUM_IRQ))
        t_ack = cocotb.start_soon(hrs_lb.gen_ack(dut, interrupts_list, gen_done, priority_list))
        await t_simultaneous_int
        gen_done.set()
        await t_ack

    if(NUM_IRQ > 1):
        gen_done.clear()
        t_all_int = cocotb.start_soon(hrs_lb.gen_all_interrupts(dut, interrupts_list, NUM_IRQ))
        t_ack = cocotb.start_soon(hrs_lb.gen_ack(dut, interrupts_list, gen_done, priority_list))
        await t_all_int
        gen_done.set()
        await t_ack

    gen_done.clear()
    t_long_seq_int = cocotb.start_soon(hrs_lb.gen_sequential_int(dut, interrupts_list, NUM_IRQ,100))
    t_ack = cocotb.start_soon(hrs_lb.gen_ack(dut, interrupts_list, gen_done, priority_list))
    await t_long_seq_int
    gen_done.set()
    await t_ack

    t_spurious_ack = cocotb.start_soon(hrs_lb.spurious_ack(dut))
    await t_spurious_ack

    t_mid_cycle = cocotb.start_soon(hrs_lb.mid_cycle_clearing_check(dut, NUM_IRQ))
    await t_mid_cycle

    t_masked = cocotb.start_soon(hrs_lb.test_masked_interrupts(dut, interrupts_list, NUM_IRQ))
    await t_masked

    t_mask_update = cocotb.start_soon(hrs_lb.test_mask_update_effect(dut, interrupts_list, NUM_IRQ))
    await t_mask_update

    t_check_reset = cocotb.start_soon(hrs_lb.check_reset_seq(dut))
    await t_check_reset

    t_priority_overlap = cocotb.start_soon(hrs_lb.test_priority_overlap(dut, interrupts_list, NUM_IRQ))
    await t_priority_overlap

    t_vector_overlap = cocotb.start_soon(hrs_lb.test_vector_overlap(dut, interrupts_list, NUM_IRQ))
    await t_vector_overlap

    if(NUM_IRQ > 1):
        t_stress = cocotb.start_soon(hrs_lb.test_stress_configuration(dut, interrupts_list, NUM_IRQ,10))
        await t_stress

    for _ in range(20): 
        await RisingEdge(dut.clk)
    test_done.set()
    await t_check_int
    return