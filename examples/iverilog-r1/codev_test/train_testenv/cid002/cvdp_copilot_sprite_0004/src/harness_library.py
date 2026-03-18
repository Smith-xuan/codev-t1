import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

# Reset the DUT (design under test)
async def reset_dut(reset_n, duration_ns=10):
    reset_n.value = 0
    await Timer(duration_ns, units="ns")
    reset_n.value = 1
    await Timer(duration_ns, units='ns')
    reset_n._log.debug("Reset complete")    

class SpriteControllerFSM:
    def __init__(self, mem_addr_width=16, pixel_width=24, sprite_width=16, sprite_height=16, wait_width=4, n_rom=256):
        # Parameters
        self.MEM_ADDR_WIDTH = mem_addr_width
        self.PIXEL_WIDTH = pixel_width
        self.SPRITE_WIDTH = sprite_width
        self.SPRITE_HEIGHT = sprite_height
        self.WAIT_WIDTH = wait_width
        self.N_ROM = n_rom

        # States
        self.IDLE = "IDLE"
        self.INIT_WRITE = "INIT_WRITE"
        self.WRITE = "WRITE"
        self.INIT_READ = "INIT_READ"
        self.READ = "READ"
        self.WAIT = "WAIT"
        self.DONE = "DONE"

        # State variables
        self.current_state = self.IDLE
        self.next_state = self.IDLE

        # Internal variables
        self.addr_counter = 0
        self.data_counter = 0
        self.wait_counter = 0

        # Outputs
        self.rw = 0
        self.write_addr = 0
        self.write_data = 0
        self.x_pos = 0
        self.y_pos = 0
        self.done = 0

    def reset(self):
        """Reset the FSM to its initial state."""
        self.current_state = self.IDLE
        self.next_state = self.IDLE
        self.addr_counter = 0
        self.data_counter = 0
        self.wait_counter = 0
        self.rw = 0
        self.write_addr = 0
        self.write_data = 0
        self.x_pos = 0
        self.y_pos = 0
        self.done = 0

    def step(self, i_wait):
        """
        Perform one step of the FSM.

        Parameters:
            i_wait (int): The wait value used during the WAIT state.
        """
        # State transitions
        if self.current_state == self.IDLE:
            self.next_state = self.INIT_WRITE
        elif self.current_state == self.INIT_WRITE:
            self.next_state = self.WRITE
        elif self.current_state == self.WRITE:
            if self.addr_counter == self.N_ROM - 1:
                self.next_state = self.INIT_READ
            else:
                self.next_state = self.WRITE
        elif self.current_state == self.INIT_READ:
            self.next_state = self.READ
        elif self.current_state == self.READ:
            if self.addr_counter == self.SPRITE_WIDTH * self.SPRITE_HEIGHT - 1:
                self.next_state = self.WAIT
            else:
                self.next_state = self.READ
        elif self.current_state == self.WAIT:
            if self.wait_counter == i_wait:
                self.next_state = self.DONE
            else:
                self.next_state = self.WAIT
        elif self.current_state == self.DONE:
            self.next_state = self.IDLE

        # State actions
        if self.current_state == self.IDLE:
            self.rw = 0
            self.addr_counter = 0
            self.data_counter = 0
            self.done = 0
        elif self.current_state == self.INIT_WRITE:
            self.rw = 1
            self.write_data = 0xFF0000
            self.write_addr = self.addr_counter
        elif self.current_state == self.WRITE:
            self.write_addr = self.addr_counter
            self.write_data = self.data_counter
            self.addr_counter += 1
            self.data_counter += 1
        elif self.current_state == self.INIT_READ:
            self.rw = 0
            self.addr_counter = 0
        elif self.current_state == self.READ:
            self.x_pos = self.addr_counter % self.SPRITE_WIDTH
            self.y_pos = self.addr_counter // self.SPRITE_WIDTH
            self.addr_counter += 1
        elif self.current_state == self.WAIT:
            self.wait_counter += 1
        elif self.current_state == self.DONE:
            self.done = 1

        # Update current state
        self.current_state = self.next_state

    def get_outputs(self):
        """
        Returns the current outputs of the FSM.

        Returns:
            dict: A dictionary containing the FSM outputs.
        """
        return {
            "rw": self.rw,
            "write_addr": self.write_addr,
            "write_data": self.write_data,
            "x_pos": self.x_pos,
            "y_pos": self.y_pos,
            "done": self.done,
        }
