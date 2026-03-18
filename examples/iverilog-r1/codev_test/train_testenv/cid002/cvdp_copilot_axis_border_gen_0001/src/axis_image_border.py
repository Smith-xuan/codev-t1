import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.triggers import ReadOnly

# Constants
IMG_WIDTH = int(cocotb.plusargs.get("IMG_WIDTH", 5))
IMG_HEIGHT = int(cocotb.plusargs.get("IMG_HEIGHT", 4))
BORDER_COLOR = int(cocotb.plusargs.get("BORDER_COLOR", 0xFFFF))


async def reset_dut(dut, duration_ns=20):
    """Reset DUT"""
    dut.resetn.value = 0
    await Timer(duration_ns, units="ns")
    dut.resetn.value = 1
    await RisingEdge(dut.clk)

def is_border_pixel(x, y):
    """Check if the pixel is a border pixel"""
    return (x == 0 or x == IMG_WIDTH + 1 or y == 0 or y == IMG_HEIGHT + 1)



async def apply_input_stream(dut, pixels):
    """Feed input stream data into DUT"""

    dut.s_axis_tuser.value = 1    
    await RisingEdge(dut.clk)
    #await Timer(60, units="ns")

    for i, pixel in enumerate(pixels):
        dut.s_axis_tdata.value = pixel
        dut.s_axis_tuser.value = 1
        dut.s_axis_tlast.value = 1 if ((i + 1) % (IMG_WIDTH) == 0) else 0

        print(f"Pixel {pixel} being sent, initial tready={dut.s_axis_tready.value}")

        await Timer(1, units="ns")
        # Wait for the DUT to signal readiness (tready=1)
        ready = int(dut.s_axis_tready.value)
        await Timer(1, units="ns")
        while not ready:
            print(f"Waiting for DUT to be ready (pixel {i}, value {pixel}, tready={dut.s_axis_tready.value})")
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")
            ready = int(dut.s_axis_tready.value)

        # # Wait for a valid-ready handshake
        # while True:
        #     await RisingEdge(dut.clk)
        #     print(f"Waiting for DUT to be ready (pixel {i}, value {pixel})")
        #     if dut.s_axis_tready.value:
        #         print("s_axis_tready: ", dut.s_axis_tready.value)
        #         break
        # Assert valid only when ready
        dut.s_axis_tvalid.value = 1
        await Timer(1, units="ns")
        print(f"Sending pixel {i} (value {pixel}, tready={dut.s_axis_tready.value}, valid={dut.s_axis_tvalid.value})")

        # Wait for a valid-ready handshake
        await RisingEdge(dut.clk)
        while not bool(dut.s_axis_tready.value):
            print(f"Waiting for handshake completion (pixel {i})")
            await RisingEdge(dut.clk)

        # Deassert valid after the handshake
        dut.s_axis_tvalid.value = 0
        print(f"Pixel {i} (value {pixel}) sent successfully")

    
    dut.s_axis_tvalid.value = 0

    dut.s_axis_tuser.value = 0
    await Timer(60, units="ns")

async def verify_output_stream(dut, expected_pixels):
    """Verify output stream from DUT"""
    received_pixels = []

    for i, expected_pixel in enumerate(expected_pixels):
        dut.m_axis_tready.value = 1
        await FallingEdge(dut.clk)
        if dut.m_axis_tvalid.value:
            received_pixels.append(int(dut.m_axis_tdata.value))
            row = i // (IMG_WIDTH + 2)  # Calculate the row from the index
            col = i % (IMG_WIDTH + 2)  # Calculate the column from the index

            # Print the index, row, column, received pixel, and tlast value
            print(f"Index: {i}, Row: {row}, Column: {col}, Pixel: {received_pixels}, tlast: {dut.m_axis_tlast.value}")

            # Check tlast for the last pixel of each row
            expected_tlast = (i + 1) % (IMG_WIDTH + 2) == 0
            assert dut.m_axis_tlast.value == expected_tlast, \
                f"Unexpected tlast signal at pixel {i}: Expected {expected_tlast}, Got {int(dut.m_axis_tlast.value)}"

            # Check pixel value
            assert int(dut.m_axis_tdata.value) == expected_pixel, \
                f"Unexpected pixel value at pixel {i}: Expected {expected_pixel}, Got {int(dut.m_axis_tdata.value)}"

    # Format received pixels into a matrix
    print("Final Output Matrix:")
    for y in range(IMG_HEIGHT + 2):  # Iterate over the height of the output image
        row = []
        for x in range(IMG_WIDTH + 2):  # Iterate over the width of the output image
            row.append(f"{received_pixels[y * (IMG_WIDTH + 2) + x]:04X}")  # Format pixel as 4-digit hexadecimal
        print(" ".join(row))  # Print the row as a space-separated string

    assert received_pixels == expected_pixels, \
        f"Output pixels mismatch: {received_pixels} != {expected_pixels}"

    await Timer(20, units="ns")

@cocotb.test()
async def test_axis_image_border_gen(dut):
    """Main test function for axis_image_border_gen"""

    dut.resetn.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.s_axis_tuser.value = 0

    dut.m_axis_tready.value = 0

    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Reset DUT
    await reset_dut(dut)

    await FallingEdge(dut.clk)

    # Prepare test data
    frame_size = (IMG_WIDTH) * (IMG_HEIGHT)
    input_pixels = [i % 0xFFFF for i in range(frame_size)]
    expected_pixels = []

    for y in range(IMG_HEIGHT + 2):
        for x in range(IMG_WIDTH + 2):
            if is_border_pixel(x, y):
                expected_pixels.append(BORDER_COLOR)
            else:
                # Map (x, y) in the core region to the input pixel index
                input_x = x - 1  # Adjust for left border
                input_y = y - 1  # Adjust for top border
                expected_pixels.append(input_pixels[input_y * IMG_WIDTH + input_x])
    
    print("Expected Pixels in Image Format:")
    for y in range(IMG_HEIGHT + 2):  # Iterate over the height of the output image
        row = []  # Collect pixels in a row
        for x in range(IMG_WIDTH + 2):  # Iterate over the width of the output image
            row.append(f"{expected_pixels[y * (IMG_WIDTH + 2) + x]:04X}")  # Format pixel as 4-digit hexadecimal
        print(" ".join(row))  # Print the row as a space-separated string

    tuser_sequence = [0]  # Frame start at the first pixel

    verify_task = cocotb.start_soon(verify_output_stream(dut, expected_pixels))
    # Apply input stream
    await apply_input_stream(dut, input_pixels)

    # Verify output stream
    await verify_task

    dut._log.info("Test completed successfully.")