import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
import harness_library as hrs_lb
import random

@cocotb.test()
async def test_0(dut):
    # Get parameter values from DUT
    WAIT_WIDTH = dut.WAIT_WIDTH.value.integer
    SPRITE_WIDTH = dut.SPRITE_WIDTH.value.integer
    SPRITE_HEIGHT = dut.SPRITE_HEIGHT.value.integer
    N_ROM = dut.N_ROM.value.integer
       
    # Instantiate the FSM model from harness_library
    fsm_model = hrs_lb.SpriteControllerFSM(
        mem_addr_width=dut.MEM_ADDR_WIDTH.value.integer,
        pixel_width=dut.PIXEL_WIDTH.value.integer,
        sprite_width=SPRITE_WIDTH,
        sprite_height=SPRITE_HEIGHT,
        wait_width=WAIT_WIDTH,
        n_rom=N_ROM,
    )

    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Initialize the DUT
    await hrs_lb.dut_init(dut) 
    
    # Reset the DUT
    await hrs_lb.reset_dut(dut.rst_n)
    # Reset the FSM model
    fsm_model.reset()
    # Wait for 1 clock cycle after reset
    await RisingEdge(dut.clk)
    # Pulse a clock to move the FSM
    fsm_model.step(0)

    # Generate a random value for i_wait
    i_wait_value = random.randint(0, 2**WAIT_WIDTH - 1)
    dut.i_wait.value = i_wait_value
    cocotb.log.info(f"Setting i_wait = {i_wait_value}")
    # Run the FSM model in parallel with the DUT
    for cycle in range(int(SPRITE_HEIGHT*SPRITE_WIDTH+N_ROM+i_wait_value)+10):
      # Step the FSM model
      fsm_model.step(i_wait=i_wait_value)

      # Wait for one clock cycle in the simulation
      await RisingEdge(dut.clk)

      # Get outputs from the FSM model
      model_outputs = fsm_model.get_outputs()

      assert dut.rw.value.integer == model_outputs["rw"], \
         f"Mismatch in 'rw' at cycle {cycle + 1}: DUT={dut.rw.value.integer}, Model={model_outputs['rw']}"

      assert dut.write_addr.value.integer == model_outputs["write_addr"], \
         f"Mismatch in 'write_addr' at cycle {cycle + 1}: DUT={dut.write_addr.value.integer}, Model={model_outputs['write_addr']}"

      assert dut.write_data.value.integer == model_outputs["write_data"], \
         f"Mismatch in 'write_data' at cycle {cycle + 1}: DUT={dut.write_data.value.integer}, Model={model_outputs['write_data']}"

      assert dut.x_pos.value.integer == model_outputs["x_pos"], \
         f"Mismatch in 'x_pos' at cycle {cycle + 1}: DUT={dut.x_pos.value.integer}, Model={model_outputs['x_pos']}"

      assert dut.y_pos.value.integer == model_outputs["y_pos"], \
         f"Mismatch in 'y_pos' at cycle {cycle + 1}: DUT={dut.y_pos.value.integer}, Model={model_outputs['y_pos']}"

      assert dut.done.value.integer == model_outputs["done"], \
         f"Mismatch in 'done' at cycle {cycle + 1}: DUT={dut.done.value.integer}, Model={model_outputs['done']}"


    cocotb.log.info(f"Test finished.")