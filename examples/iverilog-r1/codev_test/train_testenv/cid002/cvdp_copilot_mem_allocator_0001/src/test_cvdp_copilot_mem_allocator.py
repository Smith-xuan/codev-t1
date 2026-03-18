import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb



@cocotb.test()
async def test_cvdp_copilot_mem_allocator(dut): 
   # Start clock
   dut_clock_period = random.randint(2, 20) # starting from 2, t high must be integer! 
   print(f"Clk period is {dut_clock_period}")
   DUT_CLK = Clock(dut.clk, dut_clock_period, 'ns')
   await cocotb.start(DUT_CLK.start())
   dut.clk._log.info(f"clk STARTED")

   await hrs_lb.dut_init(dut)

   # Apply reset 
   await hrs_lb.reset_dut(dut.reset, dut_clock_period)

   for i in range(2):
      await RisingEdge(dut.clk)

   # Ensure  outputs reset value 
   assert dut.acquire_addr.value == 0, f"acquire_addr is not zero after reset: {dut.acquire_addr.value}"
   assert dut.empty.value == 1, f"ُempty should be asserted: {dut.empty.value}"
   assert dut.full.value == 0, f"full should be low: {dut.full.value}"

   # Get parameter values from top module
   SIZE = int(dut.SIZE.value)
   #ADDRW = int(dut.ADDRW.value)

   #1. Testing Sequential Full condition: Setting acquire request for SIZE cycles After reset (empty) should result in Full assertion
   await FallingEdge(dut.clk)
   dut.acquire_en.value = 1
   cycles_to_full = 0
   while (dut.full.value != 1):
      await RisingEdge(dut.clk)
      cycles_to_full = cycles_to_full + 1
      await FallingEdge(dut.clk)
   dut.acquire_en.value = 0
   assert cycles_to_full == SIZE, f"full should be asserted. Asserted after: {cycles_to_full}, Expected: {SIZE}"

   await hrs_lb.reset_dut(dut.reset, dut_clock_period)  

   #2. Randomly verify Allocation address/Dellocation
   mask_list = [0 for _ in range(SIZE)]  # Keep track of allocated slots
   addr_list = []  # Store allocated addresses for potential deallocation
   allocate_index = 0 # First address available for allocation is 0x0
   await FallingEdge(dut.clk)
   
   actions = [0, 1, 2]  # 0: No action, 1: Allocate, 2: Deallocate
   
   weights = [1, 3, 1]  # Higher weight for allocation (1: Allocate) #Tends to be full
   for i in range(5 * SIZE):
      dut.acquire_en.value = 0
      dut.release_en.value = 0

      action = random.choices(actions, weights=weights, k=1)[0]
      #action = random.randint(0, 2)  # 0: No action, 1: Allocate, 2: Deallocate
      
      if action == 0:
         pass

      elif action == 1:  # Allocate
         if 0 in mask_list: #Empty slot
            dut.acquire_en.value = 1
            mask_list[allocate_index] = 1  
            addr_list.append(allocate_index)
            # If not, next cycle full will be examined
            if 0 in mask_list:
               allocate_index = mask_list.index(0)         
         else:
            assert dut.full.value == 1, f"Full should be asserted when there are no empty slots"

      elif action == 2:  # Deallocate
         if addr_list:  # Only attempt deallocation if there are allocated addresses
            deallocate_index = random.choice(addr_list)  # Randomly choose an allocated address
            dut.release_en.value = 1
            dut.release_addr.value = deallocate_index
            mask_list[deallocate_index] = 0  # Mark the index as free
            addr_list.remove(deallocate_index)  # Remove from allocated list
            allocate_index = mask_list.index(0)
         else:
            assert dut.empty.value == 1, f"Empty should be asserted when there are no thing allocated"

      await RisingEdge(dut.clk)
      await FallingEdge(dut.clk)
      # Assert acquire address in case full is deasserted only.
      if (dut.full.value != 1):
         assert int(dut.acquire_addr.value) == allocate_index, f"acquire_addr mismatch Expected: {allocate_index} , dut_output: {int(dut.acquire_addr.value)} "

   weights = [1, 1, 3]  # Higher weight for deallocation (2: Deallocate) #Tends to be empty
   for i in range(5 * SIZE):
      dut.acquire_en.value = 0
      dut.release_en.value = 0

      action = random.choices(actions, weights=weights, k=1)[0]
      #action = random.randint(0, 2)  # 0: No action, 1: Allocate, 2: Deallocate
      
      if action == 0:
         pass

      elif action == 1:  # Allocate
         if 0 in mask_list: #Empty slot
            dut.acquire_en.value = 1
            mask_list[allocate_index] = 1  
            addr_list.append(allocate_index)
            # If not, next cycle full will be examined
            if 0 in mask_list:
               allocate_index = mask_list.index(0)         
         else:
            assert dut.full.value == 1, f"Full should be asserted when there are no empty slots"

      elif action == 2:  # Deallocate
         if addr_list:  # Only attempt deallocation if there are allocated addresses
            deallocate_index = random.choice(addr_list)  # Randomly choose an allocated address
            dut.release_en.value = 1
            dut.release_addr.value = deallocate_index
            mask_list[deallocate_index] = 0  # Mark the index as free
            addr_list.remove(deallocate_index)  # Remove from allocated list
            allocate_index = mask_list.index(0)
         else:
            assert dut.empty.value == 1, f"Empty should be asserted when there are no thing allocated"

      await RisingEdge(dut.clk)
      await FallingEdge(dut.clk)
      # Assert acquire address in case full is deasserted only.
      if (dut.full.value != 1):
         assert int(dut.acquire_addr.value) == allocate_index, f"acquire_addr mismatch Expected: {allocate_index} , dut_output: {int(dut.acquire_addr.value)} "




