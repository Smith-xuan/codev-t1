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
    reset_n.value = 1
    await Timer(duration_ns, units="ns")
    reset_n.value = 0
    await Timer(duration_ns, units='ns')
    reset_n._log.debug("Reset complete")   

class SGDLinearRegression:
    def __init__(self, data_width=16, learning_rate=1, debug=0):
        self.data_width = data_width
        self.learning_rate = learning_rate
        self.w = 0  # Weight (w)
        self.b = 0  # Bias (b)

        self.debug = debug

        self.bit_limit = data_width

        # Add registers for delayed updates
        self.delta_w = 0
        self.delta_b = 0
        self.reset()

    def reset(self):
        """Reset the model parameters and output signals."""
        self.w = 0
        self.b = 0
        self.delta_w = 0
        self.delta_b = 0

    def apply_bit_limit(self, value):
        # Create the mask for the given bit limit
        mask = (1 << self.bit_limit) - 1  # e.g., 4 bits -> mask = 0b1111
    
        # Limit the value to the bit range
        limited_value = value & mask
    
        # Adjust for signed representation
        if limited_value >= (1 << (self.bit_limit - 1)):
            limited_value -= (1 << self.bit_limit)
    
        return limited_value


    def update(self, reset, x_in, y_true):
        if reset:
            self.reset()
            return self.w, self.b

        self.w += self.delta_w
        self.b += self.delta_b
        self.w = self.apply_bit_limit(self.w)
        self.b = self.apply_bit_limit(self.b)

        self.y_pred = (self.w * x_in) + self.b
        self.error  = y_true - self.y_pred
        self.delta_w = self.learning_rate*self.error*x_in
        self.delta_b = self.learning_rate*self.error        

        if self.debug: 
           cocotb.log.info(f'[INPUTS] x = {x_in}, y = {y_true}')
           cocotb.log.info(f'[MODEL] w = {self.w}, b = {self.b}, error = {self.error}')
           cocotb.log.info(f'[MODEL] delta w = {self.delta_w}, delta b = {self.delta_b}')
        
        return self.w, self.b
