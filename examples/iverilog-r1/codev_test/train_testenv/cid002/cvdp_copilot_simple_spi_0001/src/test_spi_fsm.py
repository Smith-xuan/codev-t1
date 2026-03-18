import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock

def assert_equal(actual, expected, msg=""):
    """Custom assertion with message."""
    assert actual == expected, f"{msg}: Expected {expected}, but got {actual}"

@cocotb.test()
async def spi_fsm_test(dut):
    """Testbench for SPI FSM Verilog module."""

    # Setup clock: 10 ns period (100 MHz)
    clock = Clock(dut.i_clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize all inputs
    dut.i_rst_b.value = 0
    dut.i_enable.value = 0
    dut.i_fault.value = 0
    dut.i_clear.value = 0
    dut.i_data_in.value = 0

    # Wait for a few clock cycles
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)

    # Release reset and check idle state
    dut.i_rst_b.value = 1
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_spi_cs_b.value, 1, "o_spi_cs_b should be high in idle")
    assert_equal(dut.o_spi_clk.value, 0, "o_spi_clk should be low in idle")
    assert_equal(dut.o_fsm_state.value, 0b00, "FSM state should be idle")
    await RisingEdge(dut.i_clk)
    # Load data and enable transmission
    dut.i_data_in.value = 0xABCD
    dut.i_enable.value = 1

    # Check state transition to Transmit
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_fsm_state.value, 0b01, "FSM state should be transmit")
    assert_equal(dut.o_spi_cs_b.value, 0, "o_spi_cs_b should be low in transmit")

    await RisingEdge(dut.i_clk)
    # Simulate data transmission
    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 1, "Mismatch in transmitted data bit 0")
    assert_equal(dut.o_bits_left.value, 15, "o_bits_left incorrect at bit 0")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 0, "Mismatch in transmitted data bit 1")
    assert_equal(dut.o_bits_left.value, 14, "o_bits_left incorrect at bit 1")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 1, "Mismatch in transmitted data bit 2")
    assert_equal(dut.o_bits_left.value, 13, "o_bits_left incorrect at bit 2")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 0, "Mismatch in transmitted data bit 3")
    assert_equal(dut.o_bits_left.value, 12, "o_bits_left incorrect at bit 3")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 1, "Mismatch in transmitted data bit 4")
    assert_equal(dut.o_bits_left.value, 11, "o_bits_left incorrect at bit 4")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 0, "Mismatch in transmitted data bit 5")
    assert_equal(dut.o_bits_left.value, 10, "o_bits_left incorrect at bit 5")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 1, "Mismatch in transmitted data bit 6")
    assert_equal(dut.o_bits_left.value, 9, "o_bits_left incorrect at bit 6")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, 1, "Mismatch in transmitted data bit 7")
    assert_equal(dut.o_bits_left.value, 8, "o_bits_left incorrect at bit 7")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, (0xABCD >> 7) & 1, "Mismatch in transmitted data bit 8")
    assert_equal(dut.o_bits_left.value, 7, "o_bits_left incorrect at bit 8")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, (0xABCD >> 6) & 1, "Mismatch in transmitted data bit 9")
    assert_equal(dut.o_bits_left.value, 6, "o_bits_left incorrect at bit 9")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, (0xABCD >> 5) & 1, "Mismatch in transmitted data bit 10")
    assert_equal(dut.o_bits_left.value, 5, "o_bits_left incorrect at bit 10")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, (0xABCD >> 4) & 1, "Mismatch in transmitted data bit 11")
    assert_equal(dut.o_bits_left.value, 4, "o_bits_left incorrect at bit 11")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, (0xABCD >> 3) & 1, "Mismatch in transmitted data bit 12")
    assert_equal(dut.o_bits_left.value, 3, "o_bits_left incorrect at bit 12")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, (0xABCD >> 2) & 1, "Mismatch in transmitted data bit 13")
    assert_equal(dut.o_bits_left.value, 2, "o_bits_left incorrect at bit 13")

    await RisingEdge(dut.o_spi_clk)
    assert_equal(dut.o_spi_data.value, (0xABCD >> 1) & 1, "Mismatch in transmitted data bit 14")
    assert_equal(dut.o_bits_left.value, 1, "o_bits_left incorrect at bit 14")

    # Check end of transmission
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_done.value, 1, "o_done should pulse high after transmission")
    assert_equal(dut.o_fsm_state.value, 0b00, "FSM should return to idle after transmission")

    # Fault condition
    dut.i_fault.value = 1
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_fsm_state.value, 0b11, "FSM state should be error on fault")
    assert_equal(dut.o_spi_cs_b.value, 1, "o_spi_cs_b should be high in error state")
    assert_equal(dut.o_spi_clk.value, 0, "o_spi_clk should be low in error state")

    # Clear fault
    dut.i_clear.value = 1
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_fsm_state.value, 0b00, "FSM state should return to idle after clear")

    # Re-enable and test reset behavior
    dut.i_enable.value = 1
    dut.i_clear.value = 0
    dut.i_fault.value = 0
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_fsm_state.value, 0b01, "FSM should transition to transmit after enable")

    dut.i_rst_b.value = 0  # Trigger reset
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_fsm_state.value, 0b00, "FSM should reset to idle")
    assert_equal(dut.o_spi_cs_b.value, 1, "o_spi_cs_b should be high after reset")
    assert_equal(dut.o_spi_clk.value, 0, "o_spi_clk should be low after reset")
