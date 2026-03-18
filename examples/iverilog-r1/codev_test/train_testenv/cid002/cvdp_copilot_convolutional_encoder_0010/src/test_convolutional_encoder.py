import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
import random

# Testbench for the convolutional encoder
@cocotb.test()
async def test_convolutional_encoder(dut):
    """Test convolutional encoder with different input sequences including corner cases."""
    
    # Start a clock
    clock = Clock(dut.clk, 10, units="ns")  # 10ns period
    cocotb.start_soon(clock.start())  # Start the clock

    # Reset the DUT
    await reset_dut(dut)

    # Test case 1: Apply a sequence of zeros
    input_seq = [0, 0, 0, 0]
    await apply_input_sequence(dut, input_seq)

    # Test case 2: Apply a sequence of ones
    input_seq = [1, 1, 1, 1]
    await apply_input_sequence(dut, input_seq)

    # Test case 3: Apply alternating bits
    input_seq = [1, 0, 1, 0]
    await apply_input_sequence(dut, input_seq)

    # Test case 4: Random input sequence
    input_seq = [random.randint(0, 1) for _ in range(10)]
    await apply_input_sequence(dut, input_seq)

    # Test case 5: Corner case with reset asserted during sequence
    await reset_during_operation(dut)

    # Test case 6: Short sequence input
    input_seq = [1, 0]
    await apply_input_sequence(dut, input_seq)

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

async def apply_input_sequence(dut, sequence):
    """Apply an input sequence and observe the outputs."""
    for bit in sequence:
        dut.data_in.value = bit
        await RisingEdge(dut.clk)

        # Safely read the values and handle 'X' or 'Z' (unknown/uninitialized) states
        encoded_bit1 = resolve_value(dut.encoded_bit1.value)
        encoded_bit2 = resolve_value(dut.encoded_bit2.value)

        cocotb.log.info(f"data_in={bit}, encoded_bit1={encoded_bit1}, encoded_bit2={encoded_bit2}")

def resolve_value(signal):
    """Resolve signal value to 'X' or integer if it's valid."""
    if ((signal.is_resolvable) if hasattr(signal, 'is_resolvable') else (str(signal) in ('0', '1'))):
        return int(signal)
    else:
        return 'X'  # Return 'X' for unknown states

async def reset_during_operation(dut):
    """Test case where reset is asserted during operation."""
    # Apply initial data
    input_seq = [1, 1, 0]
    for bit in input_seq:
        dut.data_in.value = bit
        await RisingEdge(dut.clk)

    # Assert reset in the middle of operation
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Continue applying more data after reset
    input_seq = [0, 1, 1]
    await apply_input_sequence(dut, input_seq)
