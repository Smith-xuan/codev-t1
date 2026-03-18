import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge, First, Event, Timer
import random


@cocotb.test()
async def test_interrupt_controller(dut):
    gen_done = 0
    test_done = 0
    interrupts_list = set()
    interrupts_list_copy = set()
    priority_list = []
    wait_timers = []
    global clear_mask
    global trig_flag
    trig_flag = 0
    global flag1
    flag1 = 0
    global max_id
    
    async def copy_interrupt_list():
        global trig_flag
        while test_done == 0:
            await RisingEdge(dut.interrupt_trig)
            trig_flag = 1
            interrupts_list_copy.clear()
            interrupts_list_copy.update(interrupts_list)

        return
    
    async def update_wait_timers():
        global clear_mask
        global trig_flag
        global flag1
        global max_id

        while test_done == 0:
            await RisingEdge(dut.clk)            
            if len(interrupts_list) == 0:
                wait_timers =[0 for i in range(0,NUM_IRQ)]
                await RisingEdge(dut.interrupt_trig)
                await FallingEdge(dut.clk)
                new_copy = interrupts_list
                await Timer(25, units="ns")


                for i in range(NUM_IRQ):
                    
                    if dut.priority_override_en.value == 1 and int(dut.override_interrupt_id.value) == i:
                        priority_list[i] = int(dut.priority_override.value)
                    else:
                        priority_list[i] = (10 - i)
                    if i in new_copy:
                        wait_timers[i] += 1
                        if wait_timers[i] >= STARVATION_THRESHOLD:
                            priority_list[i] = min(15, priority_list[i] + i)
                    else:
                        wait_timers[i] = 0
                max_id = get_max_pending()


            elif dut.interrupt_ack.value == 1:
                int_list =  interrupts_list_copy
                
                await FallingEdge(dut.interrupt_valid)
                trigger = await First(
                    RisingEdge(dut.interrupt_valid),  # Wait for signal_a rising edge
                    Timer(300, units="ns")    # Or wait for 100 ns
                )

                if isinstance(trigger, RisingEdge):
                    dut._log.info("Rising edge detected on interrupt_valid")
                else:
                    continue
                for i in range(NUM_IRQ):
                    if dut.priority_override_en.value == 1 and int(dut.override_interrupt_id.value) == i:
                        priority_list[i] = int(dut.priority_override.value)
                    else:
                        priority_list[i] = (10 - i)
                    if trig_flag:
                        if i in int_list and not clear_mask[i]:
                            wait_timers[i] += 1
                            if wait_timers[i] >= STARVATION_THRESHOLD:
                                priority_list[i] = min(15, priority_list[i] + i)
                        else:
                            wait_timers[i] = 0
                    else:
                        if i in interrupts_list:
                            wait_timers[i] += 1
                            if wait_timers[i] >= STARVATION_THRESHOLD:
                                priority_list[i] = min(15, priority_list[i] + i)
                        else:
                            wait_timers[i] = 0

                interrupts_list_copy.clear()
                interrupts_list_copy.update(interrupts_list)
                trig_flag = 0
                max_id = get_max_pending()
        return
    
    def get_max_pending() -> int:
        max_p = 0
        max_i = 0
        for i in sorted(interrupts_list):
            if int(priority_list[i]) >= max_p:
                max_p = priority_list[i]
                max_i = i

        return max_i
    
    async def write_multiple_irq_req(new_interrupts):
        new_irq = dut.interrupt_requests.value
        for irq_id in new_interrupts:
            new_irq = int(new_irq) | (1 << irq_id)
        dut.interrupt_requests.value = new_irq
        dut.interrupt_trig.value = 1
        await RisingEdge(dut.clk)
        dut.interrupt_trig.value = 0
        dut.interrupt_requests.value = 0

        interrupts = ""
        for irq_id in new_interrupts:
            interrupts_list.add(irq_id)
            interrupts += ","+str(irq_id)


        await RisingEdge(dut.clk)
        cocotb.log.info(f'Simultaneous Interrupts Asserted: IDs {interrupts}')
        return

    async def write_irq_req(irq_id):
        # Set interrupt request bit
        dut.interrupt_requests.value = int(dut.interrupt_requests.value) | (1 << irq_id)
        dut.interrupt_trig.value = 1
        await RisingEdge(dut.clk)
        dut.interrupt_trig.value = 0
        dut.interrupt_requests.value = int(dut.interrupt_requests.value) & ~(1 << irq_id)
        

        interrupts_list.add(irq_id)
        cocotb.log.info(f'Interrupt Request Made: ID = {irq_id}')
        await RisingEdge(dut.clk)
        return


    async def gen_sequential_int(iter: int = 10):
        global flag1
        flag1 = 1
        cocotb.log.info('Sequential Interrupts Seq Started')

        for i in range(iter):
            while len(interrupts_list) == NUM_IRQ:
                await RisingEdge(dut.clk)

            irq_id = random.randint(0, NUM_IRQ - 1)
            while irq_id in interrupts_list:
                irq_id = random.randint(0, NUM_IRQ - 1)

            # Set interrupt request bit
            await write_irq_req(irq_id)

        cocotb.log.info('Sequential Interrupts Seq Finished')
        return

    async def gen_simultaneous_int(iter: int = 10):
        global flag1
        cocotb.log.info('Simultaneous Interrupts Seq Started')
        flag1 = 1

        for i in range(iter):
            while len(interrupts_list) >= (NUM_IRQ - 1):
                await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)

            num_of_interrupts = random.randint(2, (NUM_IRQ - len(interrupts_list)))
            new_interrupts = set()
            while len(new_interrupts) < num_of_interrupts:
                irq_id = random.randint(0, NUM_IRQ - 1)
                if irq_id not in interrupts_list:
                    new_interrupts.add(irq_id)

            await write_multiple_irq_req(new_interrupts)
            await FallingEdge(dut.clk)
        cocotb.log.info('Simultaneous Interrupts Seq Finished')
        return

    async def gen_all_interrupts():
        global flag1
        flag1 = 1
        cocotb.log.info('All Interrupts Seq Started')

        new_interrupts = set()
        for i in range(NUM_IRQ - 1):
            new_interrupts.add(i)
        await write_multiple_irq_req(new_interrupts=new_interrupts)

        cocotb.log.info('All Interrupts Seq Finished')
        return

    async def gen_ack():
        global clear_mask
        cocotb.log.info('Generate Ack Seq Started')
        while gen_done == 0 or (len(interrupts_list) > 0):
            await RisingEdge(dut.clk)

            # Wait for an active interrupt
            if dut.interrupt_valid.value == 1:
                await FallingEdge(dut.clk)
                # Random acknowledgment delay between 1 and 5 clock cycles
                for i in range(random.randint(1, 5)):
                    await RisingEdge(dut.clk)
                current_id = int(dut.interrupt_id.value)
                dut.interrupt_ack.value = 1
                await RisingEdge(dut.clk)
                dut.interrupt_ack.value = 0
                for _ in range(2):
                    await RisingEdge(dut.clk)
                interrupts_list.remove(current_id)
                clear_mask = [1 if i == current_id else 0 for i in range(NUM_IRQ)]
                await RisingEdge(dut.clk)
                cocotb.log.info(f'Interrupt Cleared: ID = {current_id}')
        cocotb.log.info('Generate Ack Seq Finished')
        return

    async def check_int_out():
        cocotb.log.info('Check interrupt_valid Signal Seq Started')
        trig_delay = 0
        flag = 0
        while test_done == 0:
            await FallingEdge(dut.clk)
            
            if (dut.rst_n.value == 0):
                assert dut.interrupt_valid.value == 0, "Interrupt signal active during reset"
            
            elif (dut.interrupt_ack.value == 1):
                for i in range(3):
                    if(dut.interrupt_trig.value == 1 and len(interrupts_list) == 0):
                        trig_delay = 3-i
                        flag = 1
                    await FallingEdge(dut.clk)

                assert dut.interrupt_valid.value == 0, "Interrupt signal active while ack is high"

            elif (len(interrupts_list) == 0 or flag):
                
                assert dut.interrupt_valid.value == 0, f"Interrupt active while {len(interrupts_list)} interrupts are pending"
                trig_delay = trig_delay if flag else 3
                if (dut.interrupt_trig.value == 0 and not flag):
                    while (dut.interrupt_trig.value == 0 and test_done == 0):
                        await FallingEdge(dut.clk)
                flag = 0

                for i in range (trig_delay):
                    await FallingEdge(dut.clk)
            else:
                assert dut.interrupt_valid.value == 1, f"No Interrupt active while {len(interrupts_list)} interrupts are pending"
        cocotb.log.info('Check interrupt_valid Signal Seq Finished')
        return
    
    
    async def check_int_id():
        global max_id
        cocotb.log.info('Check interrupt_id Signal Seq Started')
        await RisingEdge(dut.interrupt_valid)
        await FallingEdge(dut.clk)
        current_id = int(dut.interrupt_id.value)
        if current_id == max_id:
            cocotb.log.info(f"Assertion Passed: current_id = {current_id}, max_id = {max_id}")
        else:
            assert False, f"Got Wrong ID: {current_id}, expected {max_id}"

    async def mid_cycle_clearing_check():
        cocotb.log.info('Mid Cycle Interrupt Clearing Seq Started')

        irq_id = random.randint(0, NUM_IRQ - 1)
        dut.interrupt_requests.value = int(dut.interrupt_requests.value) | (1 << irq_id)
        dut.interrupt_trig.value = 1
        await FallingEdge(dut.clk)
        dut.interrupt_trig.value = 0
        dut.interrupt_requests.value = int(0)

        for _ in range(10):
            await RisingEdge(dut.clk)
            assert dut.interrupt_valid.value == 0
        cocotb.log.info('Mid Cycle Interrupt Clearing Seq Finished')
        return

    async def check_reset_seq(length: int = 10):
        cocotb.log.info('Check Reset Seq Started')
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        for _ in range(length):
            await RisingEdge(dut.clk)
            assert dut.interrupt_valid.value == 0, "ERROR | Interrupt signal not cleared on reset"
            assert dut.interrupt_status.value == 0, "ERROR | Interrupt status not cleared on reset"
        dut.rst_n.value = 1
        cocotb.log.info('Check Reset Seq Finished')
        return

    async def spurious_ack():
        cocotb.log.info('Spurious Acknowledge Test Started')
        await RisingEdge(dut.clk)
        dut.interrupt_ack.value = 1
        assert dut.interrupt_valid.value == 0, "Spurious ack triggered an interrupt"
        await RisingEdge(dut.clk)
        dut.interrupt_ack.value = 0
        assert dut.interrupt_valid.value == 0, "Interrupt signal active after spurious ack"
        await RisingEdge(dut.clk)
        cocotb.log.info('Spurious Acknowledge Test Finished')
        return

    async def test_priority_overlap():
        global flag1
        global max_id
        flag1 = 1
        cocotb.log.info('Priority Map Overlap Test Started')

        # Generate an interrupt
        for _ in range(min(5, NUM_IRQ)):
            irq_id = random.randint(0, NUM_IRQ - 1)
            while irq_id in interrupts_list:
                irq_id = random.randint(0, NUM_IRQ - 1)
            await write_irq_req(irq_id=irq_id)

        # Wait for interrupt to be active
        while dut.interrupt_valid.value != 1:
            await RisingEdge(dut.clk)

        while (len(interrupts_list) > 0):        
            expected = int(dut.interrupt_id.value)

            # Update priority map while interrupt is active
            i = random.choice(list(interrupts_list))
            dut.priority_override.value = 11
            dut.override_interrupt_id.value = i
            dut.priority_override_en.value = 1
            await RisingEdge(dut.clk)
            priority_list[i] = int(11)
            await RisingEdge(dut.clk)

            cocotb.log.info(f'New Priority Maps {priority_list}')

            # Verify current interrupt continues processing
            current_id = int(dut.interrupt_id.value)
            assert current_id == expected, f"Active interrupt changed after priority update. Expected: {expected}, Got: {current_id}"

            # Acknowledge the interrupt
            dut.interrupt_ack.value = 1
            await RisingEdge(dut.clk)
            dut.interrupt_ack.value = 0
            interrupts_list.remove(current_id)

            for _ in range(4):
                await FallingEdge(dut.clk)
            
            if (len(interrupts_list) > 0):
                expected = max_id
                current_id = int(dut.interrupt_id.value)
                assert current_id == expected, f"Active interrupt does not have highest priority. Expected: {expected}, Got: {current_id}"

            dut.priority_override_en.value = 0
            priority_list[i] = int(10 - i)

        cocotb.log.info('Priority Map Overlap Test Finished')
        return

    # Initialize signals
    dut.rst_n.value = 0
    dut.interrupt_requests.value = 0
    dut.interrupt_ack.value = 0
    dut.interrupt_trig.value = 0
    dut.override_interrupt_id.value = 0
    dut.priority_override.value = 0
    dut.priority_override_en.value = 0
    dut.reset_interrupts.value = 1
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    cocotb.log.info("Test Initialized")

    # Reset DUT
    for _ in range(3):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1
    dut.reset_interrupts.value = 0

    for _ in range(3):
        await RisingEdge(dut.clk)

    # Retrieve NUM_IRQ
    NUM_IRQ = len(dut.interrupt_requests.value)
    STARVATION_THRESHOLD = int(dut.STARVATION_THRESHOLD.value)

    priority_list = [(10 -i) for i in range(NUM_IRQ)]
    wait_timers = [0 for i in range(NUM_IRQ)]
    clear_mask = [0 for i in range(NUM_IRQ)]

    # Start main test sequences
    t_check_int = cocotb.start_soon(check_int_out())
    t_check_int_id = cocotb.start_soon(check_int_id())
    t_wait_timers = cocotb.start_soon(update_wait_timers())
    t_copy_list = cocotb.start_soon(copy_interrupt_list())
    for _ in range(10):
        await RisingEdge(dut.clk)

    t_seq_int = cocotb.start_soon(gen_sequential_int())
    t_ack = cocotb.start_soon(gen_ack())
    await t_seq_int
    gen_done = 1
    await t_ack

    for i in range (0,100):
        await RisingEdge(dut.clk)

    if(NUM_IRQ > 1):
        gen_done = 0
        t_simultaneous_int = cocotb.start_soon(gen_simultaneous_int())
        t_ack = cocotb.start_soon(gen_ack())
        await t_simultaneous_int
        gen_done = 1
        await t_ack

    if(NUM_IRQ > 1):
        gen_done = 0
        t_all_int = cocotb.start_soon(gen_all_interrupts())
        t_ack = cocotb.start_soon(gen_ack())
        await t_all_int
        gen_done = 1
        await t_ack

    gen_done = 0
    t_long_seq_int = cocotb.start_soon(gen_sequential_int(100))
    t_ack = cocotb.start_soon(gen_ack())
    await t_long_seq_int
    gen_done = 1
    await t_ack
    
    t_spurious_ack = cocotb.start_soon(spurious_ack())
    await t_spurious_ack

    t_mid_cycle = cocotb.start_soon(mid_cycle_clearing_check())
    await t_mid_cycle

    t_check_reset = cocotb.start_soon(check_reset_seq())
    await t_check_reset

    t_priority_overlap = cocotb.start_soon(test_priority_overlap())
    await t_priority_overlap


    for i in range(20): 
        await RisingEdge(dut.clk)
    test_done = 1
    await t_check_int
    await t_check_int_id
    return