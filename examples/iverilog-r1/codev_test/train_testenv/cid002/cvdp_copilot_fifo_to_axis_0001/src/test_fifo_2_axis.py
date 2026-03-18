# verif/test_fifo_2_axi_stream.py

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.result import TestSuccess
import logging
import os
import random  # For generating random data

async def reset_dut(dut, reset_time=20):
    """
    Resets the DUT by asserting and de-asserting the reset signal.
    Ensures the DUT starts from a known state.
    """
    dut.rst.value = 1
    cocotb.log.info("Applying reset...")
    await Timer(reset_time, units="ns")
    dut.rst.value = 0
    cocotb.log.info("De-asserting reset...")
    await RisingEdge(dut.i_axi_clk)
    cocotb.log.info("Waiting for DUT to stabilize after reset...")
    # Wait for a few clock cycles to let DUT stabilize
    for _ in range(5):
        await RisingEdge(dut.i_axi_clk)
    # Check that o_axi_valid is de-asserted after reset
    if dut.o_axi_valid.value == 1:
        cocotb.log.warning("DUT o_axi_valid is asserted after reset. Attempting to clear...")
        # Attempt to clear o_axi_valid by toggling i_axi_ready
        dut.i_axi_ready.value = 0
        await RisingEdge(dut.i_axi_clk)
        dut.i_axi_ready.value = 1
        await RisingEdge(dut.i_axi_clk)
        if dut.o_axi_valid.value == 1:
            cocotb.log.error("DUT o_axi_valid remains asserted after attempting to clear.")
            assert False, "DUT o_axi_valid remains asserted after reset."
    else:
        cocotb.log.info("DUT o_axi_valid is de-asserted after reset as expected.")

async def send_fifo_word(dut, data_word, user_signal, DATA_WIDTH, TIMEOUT_CYCLES=100):
    """
    Sends a single data word from the FIFO interface.
    """
    cocotb.log.info(f"Sending FIFO word: data={hex(data_word)}, user_signal={user_signal:04b}")
    
    # Assert FIFO ready and set block size and user signal
    dut.i_block_fifo_rdy.value = 1
    dut.i_block_fifo_size.value = 1
    dut.i_axi_user.value = user_signal

    # Wait for o_block_fifo_act to be asserted
    await RisingEdge(dut.i_axi_clk)
    cycles_waited = 0
    while dut.o_block_fifo_act.value == 0:
        await RisingEdge(dut.i_axi_clk)
        cycles_waited += 1
        if cycles_waited > TIMEOUT_CYCLES:
            assert False, "Timeout waiting for o_block_fifo_act to be asserted."
    cocotb.log.info("FIFO activated for reading.")

    # Await o_block_fifo_stb to be asserted
    cycles_waited = 0
    cocotb.log.info("Awaiting strobe signal for data word...")
    while dut.o_block_fifo_stb.value == 0:
        await RisingEdge(dut.i_axi_clk)
        cycles_waited += 1
        if cycles_waited > TIMEOUT_CYCLES:
            assert False, "Timeout waiting for o_block_fifo_stb to be asserted."
    cocotb.log.info("Strobe signal asserted by DUT.")

    # Set i_block_fifo_data when strobe is asserted
    fifo_data = data_word & ((1 << DATA_WIDTH) - 1)
    dut.i_block_fifo_data.value = fifo_data
    cocotb.log.info(f"Set i_block_fifo_data to {hex(fifo_data)}.")

    # Keep data stable for two cycles to ensure DUT latches it
    await RisingEdge(dut.i_axi_clk)
    await RisingEdge(dut.i_axi_clk)

    # Clear i_block_fifo_data after strobe is handled
    dut.i_block_fifo_data.value = 0
    cocotb.log.info("Cleared i_block_fifo_data after transmission.")

    # De-assert FIFO ready after block is sent
    dut.i_block_fifo_rdy.value = 0
    cocotb.log.info("De-asserted FIFO ready signal.")

async def receive_axi_stream(dut, expected_data, expected_last, expected_user, TIMEOUT_CYCLES=100):
    """
    Receives data via AXI Stream interface and verifies it against expected values.
    """
    received_data = []
    received_last = []
    received_user = []
    cycles_waited = 0

    # Set i_axi_ready to 1 to acknowledge data reception
    dut.i_axi_ready.value = 1
    cocotb.log.info("Set i_axi_ready to 1 to receive AXI Stream data.")

    while True:
        if dut.o_axi_valid.value == 1 and dut.i_axi_ready.value == 1:
            data = dut.o_axi_data.value.integer
            last = dut.o_axi_last.value
            user = dut.o_axi_user.value.integer
            received_data.append(data)
            received_last.append(last)
            received_user.append(user)
            cocotb.log.info(f"AXI Stream received data: {hex(data)}, last: {last}, user: {user:04b}")
            if last:
                break
        await RisingEdge(dut.i_axi_clk)
        cycles_waited += 1
        if cycles_waited > TIMEOUT_CYCLES:
            assert False, "Timeout waiting for AXI Stream data."

    # Assertions
    if received_data != expected_data:
        cocotb.log.error(f"Received data {received_data} does not match expected {expected_data}")
        assert False, f"Received data {received_data} does not match expected {expected_data}"
    if received_last != expected_last:
        cocotb.log.error(f"Received last signals {received_last} do not match expected {expected_last}")
        assert False, f"Received last signals {received_last} do not match expected {expected_last}"
    if received_user != [expected_user] * len(received_data):
        cocotb.log.error(f"Received user signals {received_user} do not match expected {bin(expected_user)}")
        assert False, f"Received user signals {received_user} do not match expected {bin(expected_user)}"

    cocotb.log.info("AXI Stream data received correctly.")

@cocotb.test()
async def test_single_data_word(dut):
    """
    Sends and receives a single deterministic data word to verify DUT behavior.
    """
    LOG_LEVEL = logging.INFO
    cocotb.log.setLevel(LOG_LEVEL)

    # Determine DATA_WIDTH from DUT's o_axi_data signal
    DATA_WIDTH = len(dut.o_axi_data)
    cocotb.log.info(f"Determined DATA_WIDTH from DUT: {DATA_WIDTH} bits")

    # Constants
    AXI_CLK_PERIOD = 10  # in ns
    TIMEOUT_CYCLES = 100

    # Start the AXI clock
    clock = Clock(dut.i_axi_clk, AXI_CLK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())

    # Reset DUT
    await reset_dut(dut)

    # Define test parameters
    single_data_word = 0xDE  # Example deterministic data word
    single_user_signal = 0b0001
    expected_last = [1]  # 'last' asserted on the single data word

    cocotb.log.info(f"Test Parameters - Data Word: {hex(single_data_word)}, User Signal: {bin(single_user_signal)}")

    # Start receiving AXI Stream
    receiver = cocotb.start_soon(
        receive_axi_stream(
            dut,
            expected_data=[single_data_word],
            expected_last=expected_last,
            expected_user=single_user_signal,
            TIMEOUT_CYCLES=TIMEOUT_CYCLES
        )
    )

    # Start sending FIFO word
    await send_fifo_word(
        dut,
        data_word=single_data_word,
        user_signal=single_user_signal,
        DATA_WIDTH=DATA_WIDTH,
        TIMEOUT_CYCLES=TIMEOUT_CYCLES
    )

    # Await receiver to ensure data is received
    await receiver

    # Final Assertions
    assert dut.o_block_fifo_act.value == 0, "FIFO activation should be de-asserted at the end of the test."
    assert dut.o_block_fifo_stb.value == 0, "FIFO strobe should be de-asserted at the end of the test."

    cocotb.log.info("Single Data Word Test Passed Successfully.")
    raise TestSuccess
