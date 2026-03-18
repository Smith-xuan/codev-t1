import cocotb
from cocotb.triggers import FallingEdge, RisingEdge
import random
from cocotb.triggers import Event, Timer

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    dut.interrupt_requests.value = 0
    dut.cpu_ack.value = 0
    dut.presetn.value = 0
    dut.penable.value = 0
    dut.psel.value = 0
    dut.pwrite.value = 0
    dut.paddr.value = 0
    dut.pwdata.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.presetn.value = 1
    dut.penable.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)

def normalize_angle(angle):
    """Normalize angle to be within the range of -180 to 180 degrees."""
    return (angle + 180) % 360 - 180

async def apb_write(dut, addr, data):
    """
    APB write task to write data to a specific register address.
    """
    await RisingEdge(dut.pclk)
    dut.paddr.value = addr
    dut.pwrite.value = 1
    dut.pwdata.value = data
    dut.psel.value = 1
    dut.penable.value = 0
    await RisingEdge(dut.pclk)
    dut.penable.value = 1
    while (dut.pready.value == 0):
        await RisingEdge(dut.pclk)
    dut.psel.value = 0
    dut.penable.value = 0
    cocotb.log.info(f"APB Write: Addr=0x{addr:08X}, Data=0x{data:08X}")
    return

async def apb_read(dut, addr):
    """
    APB read task to read data from a specific register address.
    """
    await RisingEdge(dut.pclk)
    dut.paddr.value = addr
    dut.pwrite.value = 0
    dut.psel.value = 1
    dut.penable.value = 0
    await RisingEdge(dut.pclk)
    dut.penable.value = 1
    await RisingEdge(dut.pclk)
    #Avoid Race Condition
    await FallingEdge(dut.pclk)
    data = int(dut.prdata.value)
    dut.psel.value = 0
    dut.penable.value = 0
    await RisingEdge(dut.pclk)
    cocotb.log.info(f"APB Read: Addr=0x{addr:08X}, Data=0x{data:08X}")
    return data

async def write_multiple_irq_req(dut, interrupts_list, new_interrupts):
   
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

async def write_irq_req(dut, interrupts_list, irq_id):
   
   # Set interrupt request bit
   dut.interrupt_requests.value = int(dut.interrupt_requests.value) | (1 << irq_id)
   await RisingEdge(dut.clk)
   dut.interrupt_requests.value = int(dut.interrupt_requests.value) & ~(1 << irq_id)
   await RisingEdge(dut.clk)
   interrupts_list.add(irq_id)
   cocotb.log.info(f'Interrupt Request Made: ID = {irq_id}')
   await RisingEdge(dut.clk)
   return

async def gen_sequential_int(dut, interrupts_list, NUM_IRQ, iter = 10):
   cocotb.log.info('Sequential Interrupts Seq Started')

   for i in range(iter):
      while len(interrupts_list) == NUM_IRQ:
            await RisingEdge(dut.clk)

      irq_id = random.randint(0, NUM_IRQ - 1)
      while irq_id in interrupts_list:
            irq_id = random.randint(0, NUM_IRQ - 1)

      # Set interrupt request bit
      await write_irq_req(dut, interrupts_list, irq_id)
      
   cocotb.log.info('Sequential Interrupts Seq Finished')
   return

async def gen_simultaneous_int(dut, interrupts_list, NUM_IRQ, iter = 10):
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

      await write_multiple_irq_req(dut,interrupts_list, new_interrupts)
      await FallingEdge(dut.clk)
   cocotb.log.info('Simultaneous Interrupts Seq Finished')
   return

async def gen_all_interrupts(dut, interrupts_list, NUM_IRQ):
   cocotb.log.info('All Interrupts Seq Started')
   
   new_interrupts = set()
   for i in range(NUM_IRQ - 1):
      new_interrupts.add(i)
   await write_multiple_irq_req(dut, interrupts_list, new_interrupts)

   cocotb.log.info('All Interrupts Seq Finished')
   return

async def gen_ack(dut, interrupts_list, gen_done, priority_list):
   cocotb.log.info('Generate Ack Seq Started')
   while((not gen_done.is_set()) or (len(interrupts_list) > 0)):
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

async def check_int_out(dut, interrupts_list, test_done):
   cocotb.log.info('Check cpu_interrupt Seq Started')
   cycles_since_req = 0
   while (not test_done.is_set()):
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

async def mid_cycle_clearing_check(dut, NUM_IRQ):
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

async def check_reset_seq(dut, length: int = 10):
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

async def spurious_ack(dut):
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

async def test_masked_interrupts(dut, interrupts_list, NUM_IRQ):
   cocotb.log.info('Masked Interrupts Seq Started')
   
   # Generate random mask
   mask = random.randint(0, (1 << NUM_IRQ) - 1)
   await apb_write(dut, 0x1, mask)
   await RisingEdge(dut.clk)

   # Generate interrupts for all bits
   new_irq = 0
   new_interrupts = set()
   for i in range(NUM_IRQ):
      new_irq = new_irq | (1 << i)
      if mask & (1 << i):  # Only add to expected list if interrupt is unmasked
            new_interrupts.add(i)
   await write_multiple_irq_req(dut, interrupts_list, new_interrupts)        
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

async def test_mask_update_effect(dut, interrupts_list, NUM_IRQ):
   cocotb.log.info('Mask Update Effect Seq Started')
   
   # Set initial mask to allow all interrupts
   await apb_write(dut, 0x1, (1 << NUM_IRQ) - 1)
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

   await write_multiple_irq_req(dut, interrupts_list, new_interrupts)

   # Mask all interrupts
   await apb_write(dut, 0x1, 0)
   interrupts_list.clear()
   await RisingEdge(dut.clk)
   # Verify no interrupts are serviced when masked
   for _ in range(10):
      await RisingEdge(dut.clk)
      assert dut.cpu_interrupt.value == 0, "Interrupt signaled while all interrupts are masked"
   
   
   dut.interrupt_requests.value = new_irq
   await RisingEdge(dut.clk)
   
   # Unmask all interrupts
   await apb_write(dut, 0x1, (1 << NUM_IRQ) - 1)
   #await RisingEdge(dut.clk)

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

async def test_priority_overlap(dut, interrupts_list, NUM_IRQ):
   cocotb.log.info('Priority Map Overlap Test Started')
   
   # Generate an interrupt
   irq_id = random.randint(0, NUM_IRQ - 1)
   await write_irq_req(dut, interrupts_list, irq_id)
   
   # Wait for interrupt to be active
   while dut.cpu_interrupt.value != 1:
      await RisingEdge(dut.clk)
   
   # Update priority map while interrupt is active
   priority_list = [(i + 1) % NUM_IRQ for i in range(NUM_IRQ)]  # Rotate priorities
   for i in range(NUM_IRQ):
      write_data = (priority_list[i] << 8) | i
      await apb_write(dut, 0x0, write_data)
      await RisingEdge(dut.clk)

   cocotb.log.info(f'New Priority Maps {priority_list}')
   await RisingEdge(dut.clk)
   
   # Verify current interrupt continues processing
   current_id = int(await apb_read(dut, 0x4))
   assert current_id == irq_id, f"Active interrupt changed after priority update. Expected: {irq_id}, Got: {current_id}"
   
   # Acknowledge the interrupt
   dut.cpu_ack.value = 1
   await RisingEdge(dut.clk)
   dut.cpu_ack.value = 0
   interrupts_list.remove(irq_id)
   
   cocotb.log.info('Priority Map Overlap Test Finished')
   return

async def test_vector_overlap(dut, interrupts_list, NUM_IRQ):
   cocotb.log.info('Vector Table Overlap Test Started')
   
   # Generate an interrupt
   irq_id = random.randint(0, NUM_IRQ - 1)
   await write_irq_req(dut, interrupts_list, irq_id)
   
   # Wait for interrupt to be active
   while dut.cpu_interrupt.value != 1:
      await RisingEdge(dut.clk)
   
   # Update vector table while interrupt is active
   new_vectors = [(i + 1) * 8 for i in range(NUM_IRQ)]  # New vector addresses
   for i in range(NUM_IRQ):
      write_data = write_data = (new_vectors[i] << 8) | i
      await apb_write(dut, 0x2, write_data)
      await RisingEdge(dut.clk)

   await RisingEdge(dut.clk)
   cocotb.log.info(f'New Vector Table Updated {new_vectors}')
   await RisingEdge(dut.clk)

   # Verify vector address remains unchanged for current interrupt
   interrupt_vector = await apb_read(dut, (int(dut.interrupt_idx.value) << 4) | 0x2)
   assert new_vectors[int(dut.interrupt_idx.value)] == interrupt_vector, \
      f"Vector address register does not match the new value. Expected: {new_vectors[int(dut.interrupt_idx.value)]}, Got: {interrupt_vector}"
   assert int(dut.interrupt_vector.value) == new_vectors[int(dut.interrupt_idx.value)], \
      f"Vector address did not change during active interrupt. Expected: {new_vectors[int(dut.interrupt_idx.value)]}, Got: {int(dut.interrupt_vector.value)}"
   
   # Acknowledge the interrupt
   dut.cpu_ack.value = 1
   await RisingEdge(dut.clk)
   dut.cpu_ack.value = 0
   interrupts_list.remove(irq_id)
   
   cocotb.log.info('Vector Table Overlap Test Finished')
   return

async def test_stress_configuration(dut, interrupts_list, NUM_IRQ, iterations=50):
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
               write_data = (priority_list[j] << 8) | j
               await apb_write(dut, 0x0, write_data)
               await RisingEdge(dut.clk)
      
      if update_mask & 2:  # Update vector table
            new_vectors = [(j + random.randint(1, 5)) * 4 for j in range(NUM_IRQ)]
            for j in range(NUM_IRQ):
               write_data = (new_vectors[j] << 8) | j
               await apb_write(dut, 0x2, write_data)
               await RisingEdge(dut.clk)

      if update_mask & 4:  # Update interrupt mask
            max_of_interrupts = random.randint(1, NUM_IRQ)
            new_mask_val = 0
            for i in range (0, max_of_interrupts):
               new_mask_val = int(new_mask_val) | (1 << i)
            write_data = new_mask_val
            await apb_write(dut, 0x1, write_data)
            await RisingEdge(dut.clk)
      
      # Wait for APB to update Regs
      await RisingEdge(dut.clk)
      
      masks = await apb_read(dut, 0x1)
      
      # Generate random interrupts
      num_interrupts = random.randint(1, max_of_interrupts)
      new_interrupts = set()

      while len(new_interrupts) < num_interrupts:
            irq_id = random.randint(0, NUM_IRQ - 1)
            if irq_id not in interrupts_list and irq_id not in new_interrupts and (masks & (1 << irq_id)):
               new_interrupts.add(irq_id)

      await write_multiple_irq_req(dut, interrupts_list, new_interrupts)

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
               current_id = int(await apb_read(dut, 0x4))# int(dut.interrupt_idx.value)
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
