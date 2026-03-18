import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, Timer

import harness_library as hrs_lb
import random

# Function to calculate the expected output based on mode
def calculate_expected_output(serial_in, prev_serial_in, mode, clk_pulse, counter, parity_state, invert_state):
    if mode == 0:  # NRZ
        return serial_in
    elif mode == 1:  # Return-to-Zero
        return serial_in and clk_pulse
    elif mode == 2:  # Differential Encoding
        return serial_in ^ prev_serial_in
    elif mode == 3:  # Inverted NRZ
        return not serial_in
    elif mode == 4:  # Alternate Inversion
        return not serial_in if invert_state else serial_in
    elif mode == 5:  # Parity-Added
        return parity_state ^ serial_in
    elif mode == 6:  # Scrambled NRZ
        return serial_in ^ (counter % 2)
    elif mode == 7:  # Edge-Triggered NRZ
        return serial_in and not prev_serial_in
    return 0

@cocotb.test()
async def test_serial_line_code_converter(dut): 
    CLK_DIV = int(dut.CLK_DIV.value)

    # Start the clock with a 10ns time period (100 MHz clock)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Initialize the DUT signals with default 0
    await hrs_lb.dut_init(dut)

    # Local variables to simulate RTL behavior
    tb_counter = 0
    tb_clk_pulse = 0
    tb_parity_state = 0
    tb_alt_invert_state = 0
    prev_serial_in = 0

    await Timer(10, units="ns")

    # Reset the DUT rst_n signal
    await hrs_lb.reset_dut(dut.reset_n, duration_ns=25, active=True)

    await RisingEdge(dut.clk) 


    # Handle reset behavior
    if dut.reset_n.value == 0:
        tb_counter = 0
        tb_clk_pulse = 0
        tb_parity_state = 0
        tb_alt_invert_state = 0
        expected_output = 0
    else:
        # Update the clock counter and pulse
        if tb_counter == CLK_DIV - 1:
            tb_counter = 0
            tb_clk_pulse = 1
        else:
            tb_counter += 1
            tb_clk_pulse = 0

        # Generate a random serial input
        serial_in = random.randint(0, 1)
        dut.serial_in.value = serial_in

        # Update parity state for odd parity
        tb_parity_state = int(dut.parity_out.value) 

        # Update alternating inversion state
        tb_alt_invert_state = not tb_alt_invert_state

    # Iterate over all modes
    for mode in range(8):
        dut.mode.value = mode

        # Simulate for 10 cycles per mode
        for i in range(10):
            # Update test state variables

            await FallingEdge(dut.clk)
            serial_in = random.randint(0, 1)
            dut.serial_in.value = serial_in


            # Calculate expected output
            expected_output = calculate_expected_output(
                serial_in,
                prev_serial_in,
                mode,
                tb_clk_pulse,
                tb_counter,
                tb_parity_state,
                tb_alt_invert_state
            )
            

            # Display current state and DUT outputs
            dut._log.info(
                f"Mode: {mode} | serial_in: {serial_in} | prev_serial_in: {prev_serial_in} | serial_out: {int(dut.serial_out.value)} "
            )
            await FallingEdge(dut.clk)
            # Check DUT output
            assert int(dut.serial_out.value) == expected_output, (
                f"Mode {mode}: Expected {expected_output}, Got {int(dut.serial_out.value)} "
                f"for serial_in={serial_in}, prev_serial_in={prev_serial_in}, clk_pulse={int(tb_clk_pulse)}, counter={tb_counter}"
            )

            # Update previous serial input
            prev_serial_in = serial_in
        


        # Add separation between modes
        await RisingEdge(dut.clk)

    # Final message
    dut._log.info("All modes and test cases passed.")
    await RisingEdge(dut.clk)
    dut.reset_n.value = 0
    await FallingEdge(dut.clk)
    assert dut.serial_out.value == 0, "serial_out should be 0 during reset"
    assert dut.clk_pulse.value == 0, "clk_pulse should be 0 during reset"
    assert dut.clk_counter.value == 0, "clk_counter should be 0 during reset"
    assert dut.prev_serial_in.value == 0, "prev_serial_in should be 0 during reset"
    assert dut.alt_invert_state.value == 0, "alt_invert_state should be 0 during reset"
    assert dut.parity_out.value == 0, "parity_out should be 0 during reset"
    await RisingEdge(dut.clk)
    dut.reset_n.value = 1
    dut._log.info("Reset behavior passed. Resuming normal operation...")

    dut.mode.value = 0

    await FallingEdge(dut.clk)
    serial_in = random.randint(0, 1)
    dut.serial_in.value = serial_in


    # Calculate expected output
    expected_output = calculate_expected_output(
        serial_in,
        prev_serial_in,
        int(dut.mode.value),
        tb_clk_pulse,
        tb_counter,
        tb_parity_state,
        tb_alt_invert_state
    )
            
    await FallingEdge(dut.clk)
    # Check DUT output
    assert int(dut.serial_out.value) == expected_output, (
        f"Mode {mode}: Expected {expected_output}, Got {int(dut.serial_out.value)} "
        f"for serial_in={serial_in}, prev_serial_in={prev_serial_in}, clk_pulse={int(dut.clk_pulse.value)}, counter={tb_counter}"
    )

    # Update previous serial input
    prev_serial_in = serial_in
        


    # Add separation between modes
    await RisingEdge(dut.clk)
