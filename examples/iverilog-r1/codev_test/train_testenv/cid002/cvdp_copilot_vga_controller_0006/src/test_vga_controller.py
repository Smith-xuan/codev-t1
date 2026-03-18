import cocotb
from cocotb.regression import TestFactory
from cocotb.triggers import RisingEdge, Timer
import random
from cocotb.result import TestSuccess

# Constants for VGA timing (640x480 @ 25 MHz)
TB_H_ACTIVE = 640
TB_H_FRONT  = 16
TB_H_PULSE  = 96
TB_H_BACK   = 48

TB_V_ACTIVE = 480
TB_V_FRONT  = 10
TB_V_PULSE  = 2
TB_V_BACK   = 33

# Clock period (25 MHz)
CLOCK_PERIOD_NS = 40

@cocotb.test()
async def test_vga_controller(dut):
    """VGA Controller Test with FSM state tracking, horizontal and vertical counters"""

    # Initialize signals
    dut.clock.value = 0
    dut.reset.value = 0
    dut.color_in.value = 0b11111111  # White color
    prev_h_state = 0
    prev_v_state = 0
    h_counter = 0
    v_counter = 0

    # Calculate total cycles (Horizontal cycles * Vertical cycles)
    h_cycles = TB_H_ACTIVE + TB_H_FRONT + TB_H_PULSE + TB_H_BACK
    v_cycles = TB_V_ACTIVE + TB_V_FRONT + TB_V_PULSE + TB_V_BACK
    total_cycles = h_cycles * v_cycles

    # Clock generation (25 MHz)
    cocotb.start_soon(clock_gen(dut, CLOCK_PERIOD_NS))

    # Apply reset
    dut.reset.value = 1
    await Timer(400, units="ns")
    dut.reset.value = 0
    dut._log.info(f"Reset de-asserted at {cocotb.regression.get_sim_time()} ns")

    # Task to monitor Horizontal FSM state transitions
    def monitor_hfsm_state():
        nonlocal prev_h_state
        h_state = int(dut.h_state.value)  # Convert to integer
        if prev_h_state != h_state:
            dut._log.info(f"[TIME {cocotb.regression.get_sim_time()} ns] Horizontal State Transition: {prev_h_state} -> {h_state}")
            prev_h_state = h_state

    # Task to monitor Vertical FSM state transitions
    def monitor_vfsm_state():
        nonlocal prev_v_state
        v_state = int(dut.v_state.value)  # Convert to integer
        if prev_v_state != v_state:
            dut._log.info(f"[TIME {cocotb.regression.get_sim_time()} ns] Vertical State Transition: {prev_v_state} -> {v_state}")
            prev_v_state = v_state

    
    # Run simulation for one complete frame
    for _ in range(total_cycles + 10):
        # Monitor FSM states and counters
        monitor_hfsm_state()
        monitor_vfsm_state()
        

        # Wait for the next rising edge of the clock
        await RisingEdge(dut.clock)

    # Finish simulation
    dut._log.info(f"Simulation complete at {cocotb.regression.get_sim_time()} ns")
    raise TestSuccess("VGA Controller test completed successfully.")

async def clock_gen(dut, period_ns):
    """Clock generation for 25 MHz signal"""
    while True:
        dut.clock.value = 0
        await Timer(period_ns / 2, units="ns")
        dut.clock.value = 1
        await Timer(period_ns / 2, units="ns")

