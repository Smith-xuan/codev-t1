import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

async def reset_dut(reset_n, duration_ns=10):
    reset_n.value = 0
    await Timer(duration_ns, units="ns")
    reset_n.value = 1
    await Timer(duration_ns, units='ns')
    reset_n._log.debug("Reset complete")  

async def extract_signed(signal, width, total_elements):
         signed_values = []
         for i in reversed(range(total_elements)):
             # Extract the unsigned value
             unsigned_value = (signal.value.to_signed() >> (width * i)) & ((1 << width) - 1)
             # Convert to signed
             signed_value = unsigned_value - (1 << width) if unsigned_value & (1 << (width - 1)) else unsigned_value
             signed_values.append(signed_value)
         return signed_values

class HMACRegInterface:
    def __init__(self, data_width=32, addr_width=4):
        self.data_width = data_width
        self.addr_width = addr_width
        self.num_regs = 2**addr_width
        self.registers = [0] * self.num_regs
        self.hmac_key = 0
        self.hmac_data = 0
        self.hmac_valid = False
        self.rdata = 0
        # FSM states
        self.IDLE = 0
        self.CHECK = 1
        self.PROCESS = 2
        self.WRITE = 3
        self.LOST = 4
        self.CHECK_KEY = 5
        self.TRIG_WAIT = 6
        self.next_state    = self.IDLE
        self.current_state = self.IDLE
        self.hmac_key_error = 0

        self.processed_data = 0

        self.rdata_delayed = 0
        self.hmac_valid_delayed = False

    def reset(self):
        """Reset the interface to its initial state."""
        self.hmac_key = 0
        self.hmac_data = 0
        self.hmac_valid = False
        self.registers = [0] * self.num_regs
        self.rdata = 0
        self.next_state    = self.IDLE
        self.current_state = self.IDLE

    def fsm(self, write_en, read_en, i_wait_en, wdata):
        self.current_state = self.next_state

        if self.current_state == self.IDLE:
            if write_en:
                self.next_state = self.CHECK

        elif self.current_state == self.CHECK:
            if wdata >> (self.data_width - 1) & 0x1 == 1:
                self.next_state = self.PROCESS
            else:
                self.next_state = self.WRITE

        elif self.current_state == self.PROCESS:
            self.next_state = self.WRITE

        elif self.current_state == self.WRITE:
            if write_en:
               self.next_state = self.IDLE
            else:
               self.next_state = self.LOST

        elif self.current_state == self.LOST:
            if read_en:
               self.next_state = self.CHECK_KEY
            else:
               self.next_state = self.LOST

        elif self.current_state == self.CHECK_KEY:
            if self.hmac_key_error:
               self.next_state = self.WRITE
            else:
               self.next_state = self.TRIG_WAIT
               
        elif self.current_state == self.TRIG_WAIT:
            if not i_wait_en:
               if self.hmac_data != 0 and self.hmac_key != 0:
                  self.next_state = self.IDLE
               else:
                  self.next_state = self.WRITE
            else:
               self.next_state = self.TRIG_WAIT
        else:
            self.next_state = self.IDLE

    def compute(self, write_en, read_en, i_wait_en, addr, wdata):
        self.hmac_valid_delayed = self.hmac_valid
        self.rdata_delayed = self.rdata
        self.fsm(write_en, read_en, i_wait_en, wdata)

        if self.current_state == self.PROCESS:
            # Create a mask with the pattern '01' repeated for the size of wdata
            mask = int('01' * (self.data_width // 2), 2)           
            # Apply the XOR operation
            self.processed_data = wdata ^ mask
        else:
            self.processed_data = wdata

        if self.hmac_key >> (self.data_width - 2) & 0x3 == 0 and self.hmac_key & 0x3 == 0:
           self.hmac_key_error = 0
        else:            
           self.hmac_key_error = 1
      
        #if write_en:
        if self.current_state == self.WRITE:
           if addr == 0:
               self.hmac_key = self.processed_data  # Write to HMAC key register
           elif addr == 1:
               self.hmac_data = self.processed_data  # Write to HMAC data register
               self.hmac_valid = 1     # Indicate valid HMAC data
           else:
               self.registers[addr] = self.processed_data  # Write to the selected register
        else:
           self.hmac_valid = 0  # Indicate valid HMAC data            
           if read_en:
              if addr == 0:
                  self.rdata = self.hmac_key  # Read HMAC key
              elif addr == 1:
                  self.rdata = self.hmac_data  # Read HMAC data
              else:
                  if 0 <= addr < self.num_regs:
                      self.rdata = self.registers[addr]  # Read from the selected register
        

        return self.rdata_delayed, self.hmac_valid_delayed
