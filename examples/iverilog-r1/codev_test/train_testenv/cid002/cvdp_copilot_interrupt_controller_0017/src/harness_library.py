import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

# ----------------------------------------
# - Apply Inputs to DUT
# ----------------------------------------

async def apply_inputs(dut, data_re, data_im, cos, sin):
   dut.i_data_re.value = data_re
   dut.i_data_im.value = data_im
   dut.i_cos.value     = cos
   dut.i_sin.value     = sin
   await RisingEdge(dut.clk)

def normalize_angle(angle):
    """Normalize angle to be within the range of -180 to 180 degrees."""
    return (angle + 180) % 360 - 180