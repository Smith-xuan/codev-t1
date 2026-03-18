import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.triggers import ReadOnly

# Constants
IMG_WIDTH_IN = int(cocotb.plusargs.get("IMG_WIDTH_IN", 10))
IMG_HEIGHT_IN = int(cocotb.plusargs.get("IMG_HEIGHT_IN", 10))
IMG_WIDTH_OUT = int(cocotb.plusargs.get("IMG_WIDTH_OUT", 5))
IMG_HEIGHT_OUT = int(cocotb.plusargs.get("IMG_HEIGHT_OUT", 5))
BORDER_COLOR = int(cocotb.plusargs.get("BORDER_COLOR", 0xFFFF))

# Define debug flags
DEBUG_LINE_BUFFER = False # Set to True to enable line buffer debug prints

async def reset_dut(dut, duration_ns=20):
    """Reset DUT"""
    dut.resetn.value = 0
    await Timer(duration_ns, units="ns")
    dut.resetn.value = 1
    await RisingEdge(dut.clk)

def is_border_pixel(x, y):
    """Check if the pixel is a border pixel"""
    return (x == 0 or x == IMG_WIDTH_OUT + 1 or y == 0 or y == IMG_HEIGHT_OUT + 1)



async def apply_input_stream(dut, pixels):
    """Feed input stream data into DUT"""

    dut.s_axis_tuser.value = 1    
    await RisingEdge(dut.clk)
    #await Timer(60, units="ns")

    for i, pixel in enumerate(pixels):
        dut.s_axis_tdata.value = pixel
        dut.s_axis_tuser.value = 1
        dut.s_axis_tlast.value = 1 if ((i + 1) % (IMG_WIDTH_IN) == 0) else 0

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

        if DEBUG_LINE_BUFFER:
            # Print line_buffer_1
            print("Line Buffer 1:")
            for i in range(IMG_WIDTH_OUT):
                value = int(dut.border_gen_inst.line_buffer_1[i].value)
                print(f"Index {i}: {value}")
    
            # Print line_buffer_2
            print("Line Buffer 2:")
            for i in range(IMG_WIDTH_OUT):
                value = int(dut.border_gen_inst.line_buffer_2[i].value)
                print(f"Index {i}: {value}")
        #endif
    
    dut.s_axis_tvalid.value = 0

    dut.s_axis_tuser.value = 0
    await Timer(60, units="ns")

async def verify_output_stream(dut, expected_pixels):
    """Verify output stream from DUT"""
    received_pixels = []

    dut.m_axis_tready.value = 1
    for i, expected_pixel in enumerate(expected_pixels):
        dut.m_axis_tready.value = 1
        await FallingEdge(dut.clk)
        dt_valid = int(dut.m_axis_tvalid.value)
        await Timer(2, units="ns")
        while not dt_valid:
            print(f"Waiting for m_axis_tvalid as 1")
            await FallingEdge(dut.clk)
            await Timer(1, units="ns")
            dt_valid = int(dut.m_axis_tvalid.value)

        await Timer(1, units="ns")
        print(f"valid: {dut.m_axis_tvalid.value}")
        if dt_valid:
            received_pixels.append(int(dut.m_axis_tdata.value))
            row = i // (IMG_WIDTH_OUT + 2)  # Calculate the row from the index
            col = i % (IMG_WIDTH_OUT + 2)  # Calculate the column from the index

            if DEBUG_LINE_BUFFER:
                print(f"border: {int(dut.border_gen_inst.is_border_pixel.value)}, x_count:{int(dut.border_gen_inst.x_count.value)}, y_count:{int(dut.border_gen_inst.y_count.value)}, read_ptr:{int(dut.border_gen_inst.read_ptr.value)}")
            # Print the index, row, column, received pixel, and tlast value
            print(f"Index: {i}, Row: {row}, Column: {col}, Pixel: {received_pixels}, tlast: {dut.m_axis_tlast.value}, valid: {dut.m_axis_tvalid.value}")

            if DEBUG_LINE_BUFFER:
                print(f"Buffer sel: R:{dut.border_gen_inst.read_buffer_select.value}, W:{dut.border_gen_inst.write_buffer_select.value}")
                
            #endif

            # Check tlast for the last pixel of each row
            expected_tlast = (i + 1) % (IMG_WIDTH_OUT + 2) == 0
            assert dut.m_axis_tlast.value == expected_tlast, \
                f"Unexpected tlast signal at pixel {i}: Expected {expected_tlast}, Got {int(dut.m_axis_tlast.value)}"

            # Check pixel value
            assert int(dut.m_axis_tdata.value) == expected_pixel, \
                f"Unexpected pixel value at pixel {i}: Expected {expected_pixel}, Got {int(dut.m_axis_tdata.value)}"

    # Format received pixels into a matrix
    print("Final Output Matrix:")
    for y in range(IMG_HEIGHT_OUT + 2):  # Iterate over the height of the output image
        row = []
        for x in range(IMG_WIDTH_OUT + 2):  # Iterate over the width of the output image
            row.append(f"{received_pixels[y * (IMG_WIDTH_OUT + 2) + x]:04X}")  # Format pixel as 4-digit hexadecimal
        print(" ".join(row))  # Print the row as a space-separated string

    assert received_pixels == expected_pixels, \
        f"Output pixels mismatch: {received_pixels} != {expected_pixels}"

    await Timer(20, units="ns")

@cocotb.test()
async def test_axis_border_gen_with_resize(dut):
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
    frame_size = (IMG_WIDTH_IN) * (IMG_HEIGHT_IN)
    input_pixels = [i % 0xFFFF for i in range(frame_size)]
    resized_pixels = [
        input_pixels[y * IMG_WIDTH_IN + x]
        for y in range(0, IMG_HEIGHT_IN, IMG_HEIGHT_IN // IMG_HEIGHT_OUT)
        for x in range(0, IMG_WIDTH_IN, IMG_WIDTH_IN // IMG_WIDTH_OUT)
    ]

    expected_pixels = []

    for y in range(IMG_HEIGHT_OUT + 2):
        for x in range(IMG_WIDTH_OUT + 2):
            if is_border_pixel(x, y):
                expected_pixels.append(BORDER_COLOR)
            else:
                # Map (x, y) in the core region to the input pixel index
                input_x = x - 1  # Adjust for left border
                input_y = y - 1  # Adjust for top border
                expected_pixels.append(resized_pixels[input_y * IMG_WIDTH_OUT + input_x])
    
    print("Expected Pixels in Image Format:")
    for y in range(IMG_HEIGHT_OUT + 2):  # Iterate over the height of the output image
        row = []  # Collect pixels in a row
        for x in range(IMG_WIDTH_OUT + 2):  # Iterate over the width of the output image
            row.append(f"{expected_pixels[y * (IMG_WIDTH_OUT + 2) + x]:04X}")  # Format pixel as 4-digit hexadecimal
        print(" ".join(row))  # Print the row as a space-separated string

    tuser_sequence = [0]  # Frame start at the first pixel

    

    verify_task = cocotb.start_soon(verify_output_stream(dut, expected_pixels))
    # Apply input stream
    await apply_input_stream(dut, input_pixels)

    # Verify output stream
    await verify_task

    dut._log.info("Test completed successfully.")