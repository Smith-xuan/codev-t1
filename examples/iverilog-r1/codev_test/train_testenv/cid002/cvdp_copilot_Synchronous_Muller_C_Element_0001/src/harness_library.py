from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random
import os

# Function to initialize DUT inputs to 0
async def dut_init(dut):
  """
  Initialize all input signals of the DUT to 0.
  
  Args:
    dut: The Design Under Test.
  """
  for signal in dut:
    if signal._type == "GPI_NET":  # Only reset input signals (GPI_NET)
      signal.value = 0

# Save VCD waveform files after the test is run
def save_vcd(wave: bool, toplevel: str, new_name: str):
  """
  Save the VCD (waveform) file if waveform generation is enabled.
  
  Args:
    wave: Boolean flag to indicate whether to save waveforms.
    toplevel: The top-level module name.
    new_name: The new name for the saved VCD file.
  """
  if wave:
    os.makedirs("vcd", exist_ok=True)  # Create the vcd folder if it doesn't exist
    os.rename(f'./sim_build/{toplevel}.fst', f'./vcd/{new_name}.fst')  # Rename and move the VCD file
    print(f"FST info: Moved /code/rundir/sim_build/{toplevel}.fst to /code/rundir/vcd/{new_name}.fst")


