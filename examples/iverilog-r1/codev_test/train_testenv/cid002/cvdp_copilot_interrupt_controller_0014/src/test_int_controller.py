import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Edge
import harness_library as hrs_lb
import random

@cocotb.test()
async def test_int_controller(dut):
    gen_done = 0
    test_done = 0
    interrupts_list = set()
    priority_list = []

    cocotb.log.info(f'Priority Map {priority_list}')
    async def write_multiple_irq_req(new_interrupts):
        
        new_irq = dut.interrupt_requests.value
        for irq_id in new_interrupts:
            new_irq = int(new_irq) | (1 << irq_id)
        dut.interrupt_requests.value = new_irq
        await RisingEdge(dut.clk)
        
        new_irq = dut.interrupt_requests.value
        for irq_id in new_interrupts:
            new_irq = int(new_irq) & ~(1 << irq_id)
        dut.interrupt_requests.value = new_irq
        await RisingEdge(dut.clk)
        for irq_id in new_interrupts:
            interrupts_list.add(irq_id)
    
        cocotb.log.info(f'Simultaneous Interrupts Asserted: IDs = {sorted(new_interrupts)}')
        return
    
    async def write_irq_req(irq_id):
        
        # Set interrupt request bit
        dut.interrupt_requests.value = int(dut.interrupt_requests.value) | (1 << irq_id)
        await RisingEdge(dut.clk)
        dut.interrupt_requests.value = int(dut.interrupt_requests.value) & ~(1 << irq_id)
        await RisingEdge(dut.clk)
        interrupts_list.add(irq_id)
        cocotb.log.info(f'Interrupt Request Made: ID = {irq_id}')
        await RisingEdge(dut.clk)
        return
    
    async def gen_sequential_int(iter : int = 10):
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
        cocotb.log.info('Simultaneous Interrupts Seq Started')

        for i in range(iter):
            while len(interrupts_list) >= (NUM_IRQ - 1):
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
        cocotb.log.info('All Interrupts Seq Started')
        
        new_interrupts = set()
        for i in range(NUM_IRQ - 1):
            new_interrupts.add(i)
        await write_multiple_irq_req(new_interrupts=new_interrupts)

        cocotb.log.info('All Interrupts Seq Finished')
        return
    
    async def gen_ack():
         cocotb.log.info('Generate Ack Seq Started')
         while(gen_done == 0 or (len(interrupts_list) > 0)):
            await RisingEdge(dut.clk)

            # Wait for an active interrupt
            if (dut.cpu_interrupt.value == 1):
               await FallingEdge(dut.clk)
               # Verify interrupt vector points to the correct interrupt
               current_id = int(dut.interrupt_idx.value)
               assert (current_id == min(interrupts_list, key=lambda i: priority_list[i])), f"Got wrong ID: {current_id}, Expected: {min(interrupts_list, key=lambda i: priority_list[i])}"
                
               # Random acknowledgment delay between 1 and 5 clock cycles
               for i in range(random.randint(1, 5)):
                  await RisingEdge(dut.clk)
               current_id = int(dut.interrupt_idx.value)
               dut.cpu_ack.value = 1
               await RisingEdge(dut.clk)
               dut.cpu_ack.value = 0
               interrupts_list.remove(current_id)
               await RisingEdge(dut.clk)
               cocotb.log.info(f'Interrupt Cleared: ID = {current_id}')
         cocotb.log.info('Generate Ack Seq Finished')
         return

    async def check_int_out():
        cocotb.log.info('Check cpu_interrupt Seq Started')
        cycles_since_req = 0
        while (test_done == 0):
            await FallingEdge(dut.clk)
            if (dut.rst_n.value == 0):
               assert (dut.cpu_interrupt.value == 0), f"Got interrupt signal while in reset"
               cycles_since_req = 0
            elif(dut.cpu_ack.value == 1):
               assert (dut.cpu_interrupt.value == 0), f"Got interrupt signal while ack is active {dut.cpu_ack.value} interrupts are pending"
               await RisingEdge(dut.clk)
               await FallingEdge(dut.clk)
               assert (dut.cpu_interrupt.value == 0), f"Got interrupt signal while ack is active {dut.cpu_ack.value} interrupts are pending"
            elif(len(interrupts_list) == 0):
               await FallingEdge(dut.clk)
               assert (dut.cpu_interrupt.value == 0), f"Got interrupt signal without any pending interrupts cpu_interrupt= {dut.cpu_interrupt.value}, number of pending interrupts {len(interrupts_list)}"
               cycles_since_req = 0
            else:
               if(cycles_since_req >= 2):
                  assert (dut.cpu_interrupt.value == 1), f"Got no interrupt signal while {len(interrupts_list)} interrupts are pending"
                  cycles_since_req = 1
               else: cycles_since_req += 1
        cocotb.log.info('Check cpu_interrupt Seq Finished')
        return
    
    async def mid_cycle_clearing_check():
        cocotb.log.info('Mid Cycle Int Clearing Seq Started')

        irq_id = random.randint(0, NUM_IRQ - 1)
        dut.interrupt_requests.value = int(dut.interrupt_requests.value) | (1 << irq_id)
        await FallingEdge(dut.clk)
        dut.interrupt_requests.value = int(0)

        for _ in range(10):
            await RisingEdge(dut.clk)
            assert (dut.cpu_interrupt.value == 0)
        cocotb.log.info('Mid Cycle Int Clearing Seq Finished')
        return
    
    async def check_reset_seq(length: int = 10):
        cocotb.log.info('Check Reset Seq Started')
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        for _ in range(length):
            await RisingEdge(dut.clk)
            assert (dut.cpu_interrupt.value == 0), f"ERROR | Interrupt Out indication is NOT cleared when reset is asserted"
            assert (dut.interrupt_service.value == 0), f"ERROR | Interrupt service bits are NOT cleared when reset is asserted"
        dut.rst_n.value = 1
        cocotb.log.info('Check Reset Seq Finished')
        return
    
    async def spurious_ack():
        cocotb.log.info('Illegal Ack Seq Started')
        await RisingEdge(dut.clk)
        dut.cpu_ack.value = 1
        assert (dut.cpu_interrupt.value == 0)
        await RisingEdge(dut.clk)
        dut.cpu_ack.value = 0
        assert (dut.cpu_interrupt.value == 0)
        await RisingEdge(dut.clk)
        assert (dut.cpu_interrupt.value == 0)
        cocotb.log.info('Illegal Ack Seq Finished')
        return

    async def test_masked_interrupts():
        cocotb.log.info('Masked Interrupts Seq Started')
        
        # Generate random mask
        mask = random.randint(0, (1 << NUM_IRQ) - 1)
        dut.interrupt_mask_value.value = mask
        dut.interrupt_mask_update.value = 1
        await RisingEdge(dut.clk)
        dut.interrupt_mask_update.value = 0
        await RisingEdge(dut.clk)
        
        # Generate interrupts for all bits
        new_irq = 0
        new_interrupts = set()
        for i in range(NUM_IRQ):
            new_irq = new_irq | (1 << i)
            if mask & (1 << i):  # Only add to expected list if interrupt is unmasked
                new_interrupts.add(i)
        await write_multiple_irq_req(new_interrupts=new_interrupts)        
        await RisingEdge(dut.clk)
        
        # Wait for all unmasked interrupts to be processed
        while len(interrupts_list) > 0:
            if dut.cpu_interrupt.value == 1:
                current_id = int(dut.interrupt_idx.value)
                # Verify only unmasked interrupts are being serviced
                assert (mask & (1 << current_id)) != 0, f"Masked interrupt {current_id} was serviced"
                assert current_id == min(interrupts_list), f"Got wrong ID: {current_id}, Expected: {min(interrupts_list)}"
                
                dut.cpu_ack.value = 1
                await RisingEdge(dut.clk)
                dut.cpu_ack.value = 0
                interrupts_list.remove(current_id)
            await RisingEdge(dut.clk)
        
        cocotb.log.info('Masked Interrupts Seq Finished')
        return

    async def test_mask_update_effect():
        cocotb.log.info('Mask Update Effect Seq Started')
        
        # Set initial mask to allow all interrupts
        dut.interrupt_mask_value.value = (1 << NUM_IRQ) - 1
        dut.interrupt_mask_update.value = 1
        await RisingEdge(dut.clk)
        dut.interrupt_mask_update.value = 0
        await RisingEdge(dut.clk)
        
        # Generate some interrupts
        new_irq = 0
        new_interrupts = set()
        for i in range(min(NUM_IRQ,3)):  # Generate 3 interrupts
            irq_id = random.randint(0, NUM_IRQ - 1)
            while irq_id in new_interrupts:
                irq_id = random.randint(0, NUM_IRQ - 1)
            new_irq = new_irq | (1 << irq_id)
            new_interrupts.add(irq_id)

        await write_multiple_irq_req(new_interrupts=new_interrupts)

        # Mask all interrupts
        dut.interrupt_mask_value.value = 0
        dut.interrupt_mask_update.value = 1
        await RisingEdge(dut.clk)
        interrupts_list.clear()
        dut.interrupt_mask_update.value = 0
        await RisingEdge(dut.clk)
        
        # Verify no interrupts are serviced when masked
        for _ in range(10):
            await RisingEdge(dut.clk)
            assert dut.cpu_interrupt.value == 0, "Interrupt signaled while all interrupts are masked"
        
         
        dut.interrupt_requests.value = new_irq
        await RisingEdge(dut.clk)
        
        # Unmask all interrupts
        dut.interrupt_mask_value.value = (1 << NUM_IRQ) - 1
        dut.interrupt_mask_update.value = 1
        await RisingEdge(dut.clk)
        dut.interrupt_mask_update.value = 0
        await RisingEdge(dut.clk)
        
        for irq_id in new_interrupts:
            interrupts_list.add(irq_id)

        dut.interrupt_requests.value = 0
        await RisingEdge(dut.clk)
        

        # Wait for all interrupts to be processed
        while len(interrupts_list) > 0:
            if dut.cpu_interrupt.value == 1:
                current_id = int(dut.interrupt_idx.value)
                assert current_id == min(interrupts_list), f"Got wrong ID: {current_id}, Expected: {min(interrupts_list)}"
                
                dut.cpu_ack.value = 1
                await RisingEdge(dut.clk)
                dut.cpu_ack.value = 0
                interrupts_list.remove(current_id)
            await RisingEdge(dut.clk)
        
        cocotb.log.info('Mask Update Effect Seq Finished')
        return
    async def test_priority_overlap():
        cocotb.log.info('Priority Map Overlap Test Started')
        
        # Generate an interrupt
        irq_id = random.randint(0, NUM_IRQ - 1)
        await write_irq_req(irq_id=irq_id)
        
        # Wait for interrupt to be active
        while dut.cpu_interrupt.value != 1:
            await RisingEdge(dut.clk)
        
        # Update priority map while interrupt is active
        priority_list = [(i + 1) % NUM_IRQ for i in range(NUM_IRQ)]  # Rotate priorities
        for i in range(NUM_IRQ):
            dut.priority_map_value[i].value = priority_list[i]

        dut.priority_map_update.value = 1
        cocotb.log.info(f'New Priority Maps {priority_list}')
        await RisingEdge(dut.clk)
        dut.priority_map_update.value = 0
        
        # Verify current interrupt continues processing
        current_id = int(dut.interrupt_idx.value)
        assert current_id == irq_id, f"Active interrupt changed after priority update. Expected: {irq_id}, Got: {current_id}"
        
        # Acknowledge the interrupt
        dut.cpu_ack.value = 1
        await RisingEdge(dut.clk)
        dut.cpu_ack.value = 0
        interrupts_list.remove(irq_id)
        
        cocotb.log.info('Priority Map Overlap Test Finished')
        return

    async def test_vector_overlap():
        cocotb.log.info('Vector Table Overlap Test Started')
        
        # Generate an interrupt
        irq_id = random.randint(0, NUM_IRQ - 1)
        original_vector = int(dut.interrupt_vector.value)
        await write_irq_req(irq_id=irq_id)
        
        # Wait for interrupt to be active
        while dut.cpu_interrupt.value != 1:
            await RisingEdge(dut.clk)
        
        # Update vector table while interrupt is active
        cocotb.log.info(f'Currnet Vector Val {int(dut.interrupt_vector.value)}')
        new_vectors = [(i + 1) * 8 for i in range(NUM_IRQ)]  # New vector addresses
        for i in range(NUM_IRQ):
            dut.vector_table_value[i].value = new_vectors[i]
        dut.vector_table_update.value = 1
        await RisingEdge(dut.clk)
        dut.vector_table_update.value = 0
        cocotb.log.info(f'New Vector Table Updated {new_vectors}')
        await RisingEdge(dut.clk)

        # Verify vector address remains unchanged for current interrupt
        assert int(dut.interrupt_vector.value) == new_vectors[int(dut.interrupt_idx.value)], \
            f"Vector did not address changed during active interrupt. Expected: {new_vectors[int(dut.interrupt_idx.value)]}, Got: {int(dut.interrupt_vector.value)}"
        
        # Acknowledge the interrupt
        dut.cpu_ack.value = 1
        await RisingEdge(dut.clk)
        dut.cpu_ack.value = 0
        interrupts_list.remove(irq_id)
        
        cocotb.log.info('Vector Table Overlap Test Finished')
        return

    async def test_stress_configuration(iterations=50):
        cocotb.log.info('Configuration Stress Test Started')
        max_of_interrupts = NUM_IRQ
        for i in range(iterations):
            cocotb.log.info(f'Stress test iteration {i + 1}/{iterations} started')

            # Randomly select which parameters to update
            update_mask = random.randint(1, 7)  # At least one parameter will be updated
            # Generate random values for each parameter
            if update_mask & 1:  # Update priority map
                priority_list = list(range(NUM_IRQ))
                random.shuffle(priority_list)
                for j in range(NUM_IRQ):
                    dut.priority_map_value[j].value = priority_list[j]
                dut.priority_map_update.value = 1
            
            if update_mask & 2:  # Update vector table
                new_vectors = [(j + random.randint(1, 5)) * 4 for j in range(NUM_IRQ)]
                for j in range(NUM_IRQ):
                    dut.vector_table_value[j].value = new_vectors[j]
                dut.vector_table_update.value = 1

            if update_mask & 4:  # Update interrupt mask
                max_of_interrupts = random.randint(1, NUM_IRQ)
                new_mask_val = 0
                for i in range (0, max_of_interrupts):
                    new_mask_val = int(new_mask_val) | (1 << i)
                dut.interrupt_mask_value.value = new_mask_val
                dut.interrupt_mask_update.value = 1
            
            # Apply updates
            await RisingEdge(dut.clk)
            
            # Clear update signals
            masks = int(dut.interrupt_mask_value.value)
            dut.priority_map_update.value = 0
            dut.vector_table_update.value = 0
            dut.interrupt_mask_update.value = 0
            
            cocotb.log.info(f'Stress test: number of pending interrupts {len(interrupts_list)}')

            # Generate random interrupts
            num_interrupts = random.randint(1, max_of_interrupts)
            new_interrupts = set()
            cocotb.log.info(f'Stress test: number of interrupts to be asserted:  {num_interrupts}')
            while len(new_interrupts) < num_interrupts:
                irq_id = random.randint(0, NUM_IRQ - 1)
                if irq_id not in interrupts_list and irq_id not in new_interrupts and (masks & (1 << irq_id)):
                    new_interrupts.add(irq_id)

            await write_multiple_irq_req(new_interrupts=new_interrupts)

            # Clear interrupt requests
            dut.interrupt_requests.value = 0
            
            # Wait for some interrupts to be processed
            wait_cycles = random.randint(1, 5)
            for _ in range(wait_cycles):
                await RisingEdge(dut.clk)
                
            # Wait for all interrupts to be processed
            while len(interrupts_list) > 0:
                if dut.cpu_interrupt.value == 1:
                    for i in range(random.randint(1, 5)):
                        await RisingEdge(dut.clk)
                    current_id = int(dut.interrupt_idx.value)
                    dut.cpu_ack.value = 1
                    await RisingEdge(dut.clk)
                    dut.cpu_ack.value = 0
                    interrupts_list.remove(current_id)
                    await RisingEdge(dut.clk)
                    cocotb.log.info(f'Interrupt Cleared: ID = {current_id}')
                await RisingEdge(dut.clk)
            
            cocotb.log.info(f'Stress test iteration {i + 1}/{iterations} completed')

        cocotb.log.info('Configuration Stress Test Finished')
        return

    # Initialize signals
    dut.rst_n.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    cocotb.log.info('Test Started')

    # Apply reset
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.interrupt_requests.value = 0
    dut.cpu_ack.value = 0

    # Initialize DUT
    # await hrs_lb.dut_init(dut)
    for _ in range(3):
        await RisingEdge(dut.clk)

    # Retrieve the parameters from the DUT    
    NUM_IRQ = int(dut.NUM_INTERRUPTS.value)
    priority_list = [i for i in range(NUM_IRQ)]

    # Start main test sequences
    t_check_int = cocotb.start_soon(check_int_out())

    t_seq_int = cocotb.start_soon(gen_sequential_int())
    t_ack = cocotb.start_soon(gen_ack())
    await t_seq_int
    gen_done = 1
    await t_ack

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

    t_masked = cocotb.start_soon(test_masked_interrupts())
    await t_masked

    t_mask_update = cocotb.start_soon(test_mask_update_effect())
    await t_mask_update

    for i in range(20): 
        await RisingEdge(dut.clk)
    test_done = 1
    await t_check_int

    t_check_reset = cocotb.start_soon(check_reset_seq())
    await t_check_reset

    t_priority_overlap = cocotb.start_soon(test_priority_overlap())
    await t_priority_overlap

    t_vector_overlap = cocotb.start_soon(test_vector_overlap())
    await t_vector_overlap

    if(NUM_IRQ > 1):
        t_stress = cocotb.start_soon(test_stress_configuration(10))
        await t_stress


    for i in range(20): 
        await RisingEdge(dut.clk)
    test_done = 1
    await t_check_int
    return