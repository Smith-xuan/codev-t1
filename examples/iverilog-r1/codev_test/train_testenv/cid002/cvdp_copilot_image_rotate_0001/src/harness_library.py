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

# Helper function to convert a 2D image into a flattened integer
def convert_2d_to_flat(array_2d, width):
  """
  Convert a 2D image into a flattened integer for passing as a plusarg to the simulator.
  
  Args:
    array_2d: The 2D image (list of lists).
    width: The bit-width of each element.
      
  Returns:
    An integer representing the flattened image.
  """
  flat_var = []
  for row in array_2d:
    for element in row:
      flat_var.append(element)

  result = 0
  for i, value in enumerate(flat_var):
    result |= (value << (i * width))  # Shift and OR to pack the bits
  return result

# Helper function to rotate a image
def calculate_rotated_image(image_in, rotation_angle, max_dim):
    """
    Calculate the expected output for a given input image and rotation angle.

    Parameters:
    - image_in: 2D list representing the input image (non-square).
    - rotation_angle: Rotation angle (0b00 = 90°, 0b01 = 180°, 0b10 = 270°, 0b11 = no rotation).
    - max_dim: Maximum dimension of the padded square image.

    Returns:
    - A 2D list of size (max_dim x max_dim) representing the expected rotated image.
    """
    # Step 1: Pad the input image to make it square
    rows = len(image_in)
    cols = len(image_in[0]) if rows > 0 else 0
    padded_image = [[0 for _ in range(max_dim)] for _ in range(max_dim)]

    for i in range(rows):
        for j in range(cols):
            padded_image[i][j] = image_in[i][j]

    # Step 2: Apply rotation based on the rotation angle
    if rotation_angle == 0b00:  # 90° Clockwise
        # Transpose and reverse rows
        rotated_image = [[padded_image[j][i] for j in range(max_dim)] for i in range(max_dim)]
        return [row[::-1] for row in rotated_image]

    elif rotation_angle == 0b01:  # 180°
        # Reverse rows and columns
        return [row[::-1] for row in padded_image[::-1]]

    elif rotation_angle == 0b10:  # 270° Counterclockwise
        # Transpose and reverse columns
        rotated_image = [[padded_image[j][i] for j in range(max_dim)] for i in range(max_dim)]
        return rotated_image[::-1]

    elif rotation_angle == 0b11:  # No rotation
        # Return the padded image as-is
        return padded_image

    else:
        raise ValueError("Invalid rotation angle")

# Helper function to convert a flattened integer back into a 2D image
def convert_flat_to_2d(flat_var, rows, cols, width):
  """
  Convert a flattened integer back into a 2D image.
  
  Args:
    flat_var: The flattened integer representing the image.
    rows: The number of rows in the image.
    cols: The number of columns in the image.
    width: The bit-width of each element.
      
  Returns:
    A 2D list (image) reconstructed from the flattened integer.
  """
  array_2d = []
  for i in range(rows):
    row = []
    for j in range(cols):
      row.append((flat_var >> (width * (i * cols + j))) & ((1 << width) - 1))  # Extract bits for each element
    array_2d.append(row)
  return array_2d

# Helper function to print a image in a readable format
def print_image(name, image):
  """
  Print the contents of a image with a label.
  
  Args:
    name: The label for the image.
    image: The 2D image to print.
  """
  print(f"Image {name}:")
  for row in image:
    print(row)
  print()

# Helper function to populate a image with random values
def populate_image(rows, cols, width):
  """
  Populate a 2D image with random integer values.
  
  Args:
    rows: Number of rows in the image.
    cols: Number of columns in the image.
    width: The bit-width of each element (values will be within this bit range).
      
  Returns:
    A randomly populated 2D image.
  """
  image = []
  for i in range(rows):
    row = []
    for j in range(cols):
      row.append(random.randint(0, (2**width)-1))  # Generate random numbers within bit-width
    image.append(row)
  return image
