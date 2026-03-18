import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random


async def reset_dut(dut, cycles=5):
    """Helper coroutine: hold aresetn low for a few cycles, then deassert."""
    dut.aresetn.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    # Wait 1 cycle for reset de-assert to propagate
    await RisingEdge(dut.aclk)


@cocotb.test()
async def test_axis_mux_basic(dut):
    """
    1) BASIC TEST
       - Round-robin across all inputs
       - Minimal handshake checks
    """
    # Start a 10 ns clock on dut.aclk
    clock = Clock(dut.aclk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Read parameter values
    c_axis_data_width  = int(dut.C_AXIS_DATA_WIDTH.value)
    c_axis_tuser_width = int(dut.C_AXIS_TUSER_WIDTH.value)
    c_axis_tid_width   = int(dut.C_AXIS_TID_WIDTH.value)
    c_axis_tdest_width = int(dut.C_AXIS_TDEST_WIDTH.value)
    num_inputs         = int(dut.NUM_INPUTS.value)

    cocotb.log.info(f"[BASIC TEST] AXIS MUX Parameters: "
                    f"DATA_WIDTH={c_axis_data_width}, "
                    f"TUSER_WIDTH={c_axis_tuser_width}, "
                    f"TID_WIDTH={c_axis_tid_width}, "
                    f"TDEST_WIDTH={c_axis_tdest_width}, "
                    f"NUM_INPUTS={num_inputs}")

    # Initialize signals
    dut.m_axis_tready.value = 1  # Always ready for basic test
    for i in range(num_inputs):
        dut.s_axis_tvalid.value[i] = 0
        dut.s_axis_tlast.value[i]  = 0
    dut.sel.value = 0

    # Reset
    await reset_dut(dut)
    cocotb.log.info("[BASIC TEST] Reset complete, starting transactions.")

    # Perform a series of 8 transactions
    total_tx = 8
    for i in range(total_tx):
        active_input = i % num_inputs
        dut.sel.value = active_input

        # Drive valid on the selected input
        dut.s_axis_tvalid.value[active_input] = 1

        # Example data pattern
        data_val = 0xA000_0000 + i
        dut.s_axis_tdata.value = data_val

        # keep
        dut.s_axis_tkeep.value = (1 << (c_axis_data_width // 8)) - 1
        # tid
        dut.s_axis_tid.value = i & ((1 << c_axis_tid_width) - 1)
        # tdest
        dut.s_axis_tdest.value = i & ((1 << c_axis_tdest_width) - 1)
        # tuser
        dut.s_axis_tuser.value = i & ((1 << c_axis_tuser_width) - 1)

        # LAST only on final transaction
        if i == (total_tx - 1):
            dut.s_axis_tlast.value[active_input] = 1

        # Wait until handshake occurs
        handshake_done = False
        wait_count = 0
        max_wait_cycles = 200  # avoid infinite loop
        while not handshake_done:
            await RisingEdge(dut.aclk)
            wait_count += 1
            if wait_count > max_wait_cycles:
                raise AssertionError("No handshake in 'test_axis_mux_basic' within 200 cycles.")
            if dut.m_axis_tvalid.value and dut.m_axis_tready.value:
                handshake_done = True

        # Log handshake
        cocotb.log.info(
            f"[BASIC TEST] TX #{i} @ input[{active_input}]  DATA=0x{data_val:08X} "
            f"TID={int(dut.s_axis_tid.value)} TDEST={int(dut.s_axis_tdest.value)} "
            f"TUSER={int(dut.s_axis_tuser.value)} LAST={dut.s_axis_tlast.value[active_input]} [HANDSHAKE]"
        )

        # De-assert signals for that input
        dut.s_axis_tvalid.value[active_input] = 0
        dut.s_axis_tlast.value[active_input]  = 0

    cocotb.log.info("[BASIC TEST] All transactions done. Basic test complete!")


@cocotb.test()
async def test_axis_mux_single_input(dut):
    """
    2) SINGLE INPUT TEST
       - Always uses input[0].
       - sel=0 always, so we don't stall waiting for handshake.
    """
    clock = Clock(dut.aclk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Read params if needed
    num_inputs = int(dut.NUM_INPUTS.value)

    # Reset
    await reset_dut(dut)
    cocotb.log.info("[SINGLE INPUT TEST] Starting. Only input[0] will drive data, sel=0 always.")

    # Setup
    dut.m_axis_tready.value = 1
    dut.sel.value = 0  # Force selection to input[0]
    for i in range(num_inputs):
        dut.s_axis_tvalid.value[i] = 0
        dut.s_axis_tlast.value[i]  = 0

    # Always drive valid from input[0]
    dut.s_axis_tvalid.value[0] = 1

    # Send 5 transactions
    for i in range(5):
        data_val = 0x1234_0000 + i
        dut.s_axis_tdata.value = data_val

        # Wait for handshake
        got_handshake = False
        wait_count = 0
        max_wait_cycles = 200
        while not got_handshake:
            await RisingEdge(dut.aclk)
            wait_count += 1
            if wait_count > max_wait_cycles:
                raise AssertionError("No handshake in 'test_axis_mux_single_input' within 200 cycles.")
            if dut.m_axis_tvalid.value and dut.m_axis_tready.value:
                got_handshake = True

        cocotb.log.info(f"[SINGLE INPUT TEST] TX #{i}, DATA=0x{data_val:08X}, HANDSHAKEN (sel=0)!")

    # De-assert input[0]
    dut.s_axis_tvalid.value[0] = 0
    cocotb.log.info("[SINGLE INPUT TEST] Complete.")


@cocotb.test()
async def test_axis_mux_with_backpressure(dut):
    """
    3) BACKPRESSURE TEST
       - We will toggle m_axis_tready to 0 occasionally to verify the DUT
         properly stalls and doesn't lose data.
    """
    clock = Clock(dut.aclk, 10, units="ns")
    cocotb.start_soon(clock.start())

    num_inputs = int(dut.NUM_INPUTS.value)

    await reset_dut(dut)
    cocotb.log.info("[BACKPRESSURE TEST] Starting. Toggling m_axis_tready periodically.")

    # Initialize
    for i in range(num_inputs):
        dut.s_axis_tvalid.value[i] = 0
        dut.s_axis_tlast.value[i]  = 0
    dut.sel.value = 0

    # We'll drive from input[0]
    input_idx = 0
    dut.s_axis_tvalid.value[input_idx] = 1

    transactions = 5
    for i in range(transactions):
        data_val = 0xBEEF_0000 + i
        dut.s_axis_tdata.value = data_val

        # Randomly set m_axis_tready to 0 for a few cycles
        if random.random() < 0.3:
            dut.m_axis_tready.value = 0
            stall_cycles = random.randint(1, 3)
            cocotb.log.info(f"[BACKPRESSURE TEST] Stalling output for {stall_cycles} cycles.")
            for _ in range(stall_cycles):
                await RisingEdge(dut.aclk)
            dut.m_axis_tready.value = 1

        # Wait for handshake
        handshake = False
        wait_count = 0
        max_wait_cycles = 200
        while not handshake:
            await RisingEdge(dut.aclk)
            wait_count += 1
            if wait_count > max_wait_cycles:
                raise AssertionError("No handshake in 'test_axis_mux_with_backpressure' within 200 cycles.")
            if dut.m_axis_tvalid.value and dut.m_axis_tready.value:
                handshake = True

        cocotb.log.info(f"[BACKPRESSURE TEST] TX #{i} DATA=0x{data_val:08X} [HANDSHAKE]")

    # Finish
    dut.s_axis_tvalid.value[input_idx] = 0
    cocotb.log.info("[BACKPRESSURE TEST] Complete.")


@cocotb.test()
async def test_axis_mux_random(dut):
    """
    4) RANDOM TEST
       - Random 'sel' each cycle
       - Random tvalid per input
       - Random toggling of m_axis_tready
       - Verifies correct data is passed when a handshake occurs
    """
    clock = Clock(dut.aclk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)
    cocotb.log.info("[RANDOM TEST] Starting random scenario...")

    num_inputs = int(dut.NUM_INPUTS.value)
    c_axis_data_width = int(dut.C_AXIS_DATA_WIDTH.value)

    # Initialize
    for i in range(num_inputs):
        dut.s_axis_tvalid.value[i] = 0
        dut.s_axis_tlast.value[i]  = 0
    dut.sel.value = 0
    dut.m_axis_tready.value = 1

    sim_cycles = 50
    for cycle in range(sim_cycles):
        await RisingEdge(dut.aclk)

        # Randomly pick sel
        random_sel = random.randint(0, num_inputs - 1)
        dut.sel.value = random_sel

        # Random toggling of m_axis_tready
        dut.m_axis_tready.value = 1 if random.random() > 0.2 else 0

        # For each input, 50% chance to drive valid
        for inp in range(num_inputs):
            if random.random() < 0.5:
                dut.s_axis_tvalid.value[inp] = 1
                # random data
                data_val = random.randint(0, 2**c_axis_data_width - 1)
                dut.s_axis_tdata.value = data_val
            else:
                dut.s_axis_tvalid.value[inp] = 0

        # Optionally log handshake if it occurs
        if dut.m_axis_tvalid.value and dut.m_axis_tready.value:
            cocotb.log.info(
                f"[RANDOM TEST] Cycle={cycle}, Handshake => SEL={int(dut.sel.value)}, "
                f"DATA=0x{dut.m_axis_tdata.value.integer:08X}"
            )

    # De-assert
    for i in range(num_inputs):
        dut.s_axis_tvalid.value[i] = 0

    cocotb.log.info("[RANDOM TEST] Complete.")
