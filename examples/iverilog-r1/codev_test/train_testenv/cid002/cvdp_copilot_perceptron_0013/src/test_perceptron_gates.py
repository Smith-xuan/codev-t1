import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_perceptron_gates(dut):
    """Testbench for the perceptron_gates module using Cocotb."""

    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset logic
    dut.rst_n.value = 0
    await Timer(10, units="ns")
    dut.rst_n.value = 1

    # Initialize inputs
    dut.x1.value = 0
    dut.x2.value = 0
    dut.learning_rate.value = 1
    dut.threshold.value = 0
    dut.gate_select.value = 0

    await RisingEdge(dut.rst_n)
    await Timer(10, units="ns")

    # Helper function for applying stimulus and logging outputs
    async def apply_stimulus(x1, x2, gate_select, duration):
        dut.x1.value = x1
        dut.x2.value = x2
        dut.gate_select.value = gate_select
        await Timer(duration, units="ns")
        cocotb.log.info(f"gate_select={gate_select}, x1={x1}, x2={x2}, percep_w1={dut.percep_w1.value.to_signed()}, percep_w2={dut.percep_w2.value.to_signed()}, percep_bias={dut.percep_bias.value.to_signed()}, present_addr={bin(dut.present_addr.value.integer)}, stop={bin(dut.stop.value.integer)}, input_index={bin(dut.input_index.value.integer)}, y_in={dut.y_in.value.to_signed()}, y={dut.y.value.to_signed()}, prev_percep_wt_1={dut.prev_percep_wt_1.value.to_signed()}, prev_percep_wt_2={dut.prev_percep_wt_2.value.to_signed()}, prev_percep_bias={dut.prev_percep_bias.value.to_signed()}")

    # Test AND gate targets (gate_select = 2'b00)
    dut.gate_select.value = 0b00
    cocotb.log.info("Start of AND gate Training")
    await apply_stimulus(1, 1, 0b00, 90)
    await apply_stimulus(1, -1, 0b00, 90)
    await apply_stimulus(-1, 1, 0b00, 100)
    await apply_stimulus(-1, -1, 0b00, 95)
    await apply_stimulus(1, 1, 0b00, 15)
    await Timer(25, units="ns")
    await apply_stimulus(1, -1, 0b00,75)
    await Timer(30, units="ns")
    await apply_stimulus(-1, 1, 0b00, 70)
    await Timer(30, units="ns")
    await apply_stimulus(-1, -1, 0b00, 60)
    assert dut.percep_w1.value.to_signed() == 1, f"Expected w1=1, but got {dut.percep_w1.value}"
    assert dut.percep_w2.value.to_signed() == 1, f"Expected w2=1, but got {dut.percep_w2.value}"
    assert dut.percep_bias.value.to_signed() == -1, f"Expected bias=-1, but got {dut.percep_bias.value}"
    cocotb.log.info("End of AND gate Training")
    

    # Test OR gate targets (gate_select = 2'b01)
    dut.gate_select.value = 0b01
    cocotb.log.info("Start of OR gate Training")
    await Timer(30, units="ns")
    await apply_stimulus(1, 1, 0b01, 75)
    await Timer(30, units="ns")
    await apply_stimulus(-1, 1, 0b01, 75)
    await Timer(30, units="ns")
    await apply_stimulus(1, -1, 0b01, 65)
    await Timer(30, units="ns")
    await apply_stimulus(-1, -1, 0b01, 60)
    assert dut.percep_w1.value.to_signed() == 1, f"Expected w1=1, but got {dut.percep_w1.value}"
    assert dut.percep_w2.value.to_signed() == 1, f"Expected w2=1, but got {dut.percep_w2.value}"
    assert dut.percep_bias.value.to_signed() == 1, f"Expected bias=1, but got {dut.percep_bias.value}"
    cocotb.log.info("End of OR gate Training")

    # Test NAND gate targets (gate_select = 2'b10) . Continue this from tomorrow
    dut.gate_select.value = 0b10
    cocotb.log.info("Start of NAND gate Training")
    await apply_stimulus(-1, -1, 0b10, 115)
    await Timer(30, units="ns")
    await apply_stimulus(-1, 1, 0b10, 70)
    await Timer(30, units="ns")
    await apply_stimulus(1, -1, 0b10, 65)
    await Timer(30, units="ns")
    await apply_stimulus(1, 1, 0b10, 65)
    assert dut.percep_w1.value.to_signed() == -1, f"Expected w1=-1, but got {dut.percep_w1.value}"
    assert dut.percep_w2.value.to_signed() == -1, f"Expected w2=-1, but got {dut.percep_w2.value}"
    assert dut.percep_bias.value.to_signed() == 1, f"Expected bias=1, but got {dut.percep_bias.value}"
    cocotb.log.info("End of NAND gate Training")

    # Test NOR gate targets (gate_select = 2'b11)
    dut.gate_select.value = 0b11
    cocotb.log.info("Start of NOR gate Training")
    await apply_stimulus(-1, -1, 0b11, 410)
    await Timer(20, units="ns")
    await apply_stimulus(-1, 1, 0b11, 80)
    await Timer(20, units="ns")
    await apply_stimulus(1, -1, 0b11, 80)
    await apply_stimulus(1, 1, 0b11, 85)
    await Timer(50, units="ns")
    await apply_stimulus(-1, -1, 0b11, 50)
    await apply_stimulus(-1, 1, 0b11, 10)
    await Timer(20, units="ns")
    await apply_stimulus(1, -1, 0b11, 80)
    await Timer(20, units="ns")
    await apply_stimulus(1, 1, 0b11, 70)
    assert dut.percep_w1.value.to_signed() == -1, f"Expected w1=-1, but got {dut.percep_w1.value}"
    assert dut.percep_w2.value.to_signed() == -1, f"Expected w2=-1, but got {dut.percep_w2.value}"
    assert dut.percep_bias.value.to_signed() == -1, f"Expected bias=1, but got {dut.percep_bias.value}"
    cocotb.log.info("End of NOR gate Training")

    # Randomized test cases
    num_random_cases = 10  # Number of random test cases
    for i in range(num_random_cases):
        random_gate_select = random.randint(0, 3)  # Randomly select gate (0b00 to 0b11)
        random_inputs = [(random.choice([-1, 1]), random.choice([-1, 1])) for _ in range(4)]

        dut.gate_select.value = random_gate_select
        cocotb.log.info(f"Start of Random Test Case {i+1} for gate_select={bin(random_gate_select)}")

        for x1, x2 in random_inputs:
            await apply_stimulus(x1, x2, random_gate_select, 100)
        cocotb.log.info(f"End of Random Test Case {i+1} for gate_select={bin(random_gate_select)}")

    # Stop the test
    cocotb.log.info("Test Completed")

