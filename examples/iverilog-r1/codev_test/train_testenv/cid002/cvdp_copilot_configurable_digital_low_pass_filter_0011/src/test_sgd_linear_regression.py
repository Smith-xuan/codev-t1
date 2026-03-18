import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import harness_library as hrs_lb  # Import the harness library for DUT initialization and reset
import random

@cocotb.test()
async def test_sgd_linear_regression(dut):
    """Test the SGD Linear Regression module with edge cases and random data."""

    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Debug mode
    debug = 0
    
    # Retrieve parameters from the DUT
    DATA_WIDTH   = int(dut.DATA_WIDTH.value)
    LEARNING_RATE = int(dut.LEARNING_RATE.value)

    model = hrs_lb.SGDLinearRegression(data_width=DATA_WIDTH, learning_rate=LEARNING_RATE, debug=debug)
    # Initialize DUT using harness library
    await hrs_lb.dut_init(dut)

    # Apply reset and enable using harness library
    await hrs_lb.reset_dut(dut.reset)
    model.reset()

    await RisingEdge(dut.clk)
    # Range for input values
    x_min = int(-2**(DATA_WIDTH - 1))
    x_max = int(2**(DATA_WIDTH - 1) - 1)

    # Number of random test iterations
    num_iterations = 10

    # Run multiple test cases
    for test_num in range(num_iterations):
        # Generate random inputs
        x_in   = random.randint(x_min, x_max)
        y_true = random.randint(x_min, x_max)

        # Apply inputs to DUT
        dut.x_in.value = x_in
        dut.y_true.value = y_true

        await RisingEdge(dut.clk)

        expected_w, expected_b = model.update(reset=0, x_in=x_in, y_true=y_true)
        # Read outputs from DUT
        dut_w = dut.w_out.value.to_signed()
        dut_b = dut.b_out.value.to_signed()

        if debug: 
           dut_error = dut.error.value.to_signed()
           dut_dw    = dut.delta_w.value.to_signed()
           dut_db    = dut.delta_b.value.to_signed()           
           cocotb.log.info(f'[DUT]   w = {dut_w}, b = {dut_b}, error = {dut_error}')        
           cocotb.log.info(f'[DUT] delta w = {dut_dw}, delta b = {dut_db}')
           cocotb.log.info(f"[Test {test_num + 1}]")
        
        assert dut_w == expected_w
        assert dut_b == expected_b

    cocotb.log.info(f"All {num_iterations} tests completed.")