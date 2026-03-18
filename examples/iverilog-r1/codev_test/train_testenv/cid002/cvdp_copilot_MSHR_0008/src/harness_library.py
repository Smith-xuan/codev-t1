
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random




async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

async def reset_dut(reset, duration_ns = 10):
    # Restart Interface
    reset.value = 0
    await Timer(duration_ns, units="ns")
    reset.value = 1
    await Timer(duration_ns, units="ns")
    reset.value = 0
    await Timer(duration_ns, units='ns')
    reset._log.debug("Reset complete")


    
    
class mshr_entry:
    """A class to represent an mshr entry."""
    def __init__(self, idx, addr, rw, data):
        self.addr = addr
        self.rw = rw
        self.data = data
        self.idx = idx
        self.next = None
    def display(self):
        print(f"MSHR ENTRY ({self.idx}): addr = {self.addr}, rw = {self.rw}, data = {self.data}, next = {self.next}")

class MSHR:
    def __init__(self, size):
        self.entries = [None] * size  
        self.size = size


    def allocate(self, addr, rw, data):
        
        # Get first available entry if any!
        new_entry_idx = -1 
        prev_idx = -1
        pending = False
        for i, entry in enumerate(self.entries):
            if  entry == None: 
                new_entry_idx = i
                break
        if new_entry_idx != -1:
            for i, entry in enumerate(self.entries):
                if entry: # not none
                    if entry.addr == addr and entry.next == None:
                        entry.next = new_entry_idx
                        pending = True
                        prev_idx = i
            new_entry = mshr_entry(new_entry_idx, addr, rw, data)
            self.entries[new_entry_idx] = new_entry

        else:
            print("cctb: MSHR is full, not slots allocated!")
        return (new_entry_idx, pending, prev_idx)
               

    def finalize(self, idx):
        assert self.entries[idx] !=None, f"cctb: Error finalizing an empty slot!"
        self.entries[idx] = None

    
    def fill_req(self, idx):
        assert self.entries[idx] !=None, f"cctb: Error fill to an empty slot!" 
        no_linked_nodes = 0
        current_entry = self.entries[idx]
        while current_entry.next !=None:
            no_linked_nodes +=1
            current_entry = self.entries[current_entry.next]
        return no_linked_nodes
    
    def get_next_idx(self,idx):
        assert self.entries[idx] !=None, f"cctb: Error EMPTY!"
        next_idx = -1
        if self.entries[idx].next != None:
            next_idx = self.entries[idx].next
        return next_idx
    
    def dequeu_req (self, idx):
        assert self.entries[idx] !=None, f"cctb: Error dequeu  an empty slot!"
        tmp = self.entries[idx]
        self.entries[idx] = None
        return tmp

    def clear(self):
        self.entries = [None] * self.size 
    
        
    def print_mshr(self):
        for i, entry in enumerate(self.entries):
            if entry:
                entry.display()