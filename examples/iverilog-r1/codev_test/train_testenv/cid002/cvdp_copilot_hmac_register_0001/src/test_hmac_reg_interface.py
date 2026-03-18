import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random
import harness_library as hrs_lb

@cocotb.test()
async def test_hmac_reg_interface(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    debug = 1

    DATA_WIDTH = dut.DATA_WIDTH.value.integer
    ADDR_WIDTH = dut.ADDR_WIDTH.value.integer

    model = hrs_lb.HMACRegInterface(DATA_WIDTH, ADDR_WIDTH)

    # Initialize DUT
    await hrs_lb.dut_init(dut)
    # Apply reset
    await hrs_lb.reset_dut(dut.rst_n)
    await RisingEdge(dut.clk)
    model.reset()

    # Calculate min and max values for data and coefficients
    data_min = 0
    data_max = int(2**DATA_WIDTH - 1)
    addr_min = 0
    addr_max = int(2**ADDR_WIDTH - 1)

    # Track visited states
    visited_states = set()

    # Create address vector
    addr_vector = [0, 1] + random.sample(range(0, addr_max + 1), addr_max - 2)
    cocotb.log.warning(f"Running WRITE OPERATION {len(addr_vector)} cycles")
    for i, addr in enumerate(addr_vector):
        write = random.choice([0, 1])
        if i == 0:
            write = 1
            data = data_min  # Use data_min in the first cycle
        elif i == 1:
            write = 1
            data = data_max  # Use data_max in the second cycle
        else:
            write = random.choice([0, 1])
            data = random.randint(data_min, data_max)  # Random for subsequent cycles
        read = not write

        dut.write_en.value = write
        dut.read_en.value = read
        dut.addr.value = addr
        dut.wdata.value = data

        await RisingEdge(dut.clk)
        exp_rdata, exp_hmac_valid = model.compute(write, read, 0, addr, data)
        dut_rdata = dut.rdata.value.integer
        dut_hmac_valid = dut.hmac_valid.value.integer

        # Track the current state of the DUT
        current_state = dut.current_state.value.integer
        visited_states.add(current_state)

        if debug and i < 10:
            cocotb.log.info(f"Test cycle number : {i}")
            cocotb.log.info(f"write_en = {write}, read_en = {read}, addr = {addr}, data = {data}")
            cocotb.log.info(f"[STATE] model = {model.current_state}, dut = {current_state}")
            cocotb.log.info(f"[PROC DATA] model = {model.processed_data}, dut = {dut.xor_data.value.integer} ")

            #dut_values = [dut.registers.value[i].to_unsigned() for i in range(addr_max+1)]
            #cocotb.log.info(f"[REGs] \tmodel = {model.registers}, \n \tdut   = {dut_values}")
            cocotb.log.info(f"exp_rdata = {exp_rdata}, exp_hmac_valid = {exp_hmac_valid}")
            cocotb.log.info(f"dut_rdata = {dut_rdata}, dut_hmac_valid = {dut_hmac_valid} \n")

        assert dut_rdata == exp_rdata
        assert dut_hmac_valid == exp_hmac_valid


    # Apply reset again
    await hrs_lb.dut_init(dut)
    await hrs_lb.reset_dut(dut.rst_n)
    model.reset()

    cocotb.log.warning(f"ASSERTION After reset")
    # Checks after Reset
    assert dut_rdata == exp_rdata
    assert dut_hmac_valid == exp_hmac_valid    

    if debug:
        cocotb.log.info(f"write_en = {write}, read_en = {read}, addr = {addr}, data = {data}")
        cocotb.log.info(f"[STATE] model = {model.current_state}, dut = {dut.current_state.value.integer} ")
        cocotb.log.info(f"[PROC DATA] model = {model.processed_data}, dut = {dut.xor_data.value.integer} ")
        #dut_values = [dut.registers.value[i].to_unsigned() for i in range(addr_max+1)]
        #cocotb.log.info(f"[REGs] \tmodel = {model.registers}, \n \tdut   = {dut_values}")
        cocotb.log.info(f"exp_rdata = {exp_rdata}, exp_hmac_valid = {exp_hmac_valid}")
        cocotb.log.info(f"dut_rdata = {dut_rdata}, dut_hmac_valid = {dut_hmac_valid} \n")

    await RisingEdge(dut.clk)

    cocotb.log.warning(f"Running again after the reset \n\n")
    for addr in addr_vector:
        write = random.choice([0, 1])
        read = not write
        data = random.randint(data_min, data_max)

        dut.write_en.value = write
        dut.read_en.value = read
        dut.addr.value = addr
        dut.wdata.value = data

        await RisingEdge(dut.clk)
        exp_rdata, exp_hmac_valid = model.compute(write, read, 0, addr, data)
        dut_rdata = dut.rdata.value.integer
        dut_hmac_valid = dut.hmac_valid.value.integer

        # Track the current state of the DUT
        current_state = dut.current_state.value.integer
        visited_states.add(current_state)

        if debug:
            cocotb.log.info(f"write_en = {write}, read_en = {read}, addr = {addr}, data = {data}")
            cocotb.log.info(f"[STATE] model = {model.current_state}, dut = {dut.current_state.value.integer} ")
            cocotb.log.info(f"[PROC DATA] model = {model.processed_data}, dut = {dut.xor_data.value.integer} ")

            #dut_values = [dut.registers.value[i].to_unsigned() for i in range(addr_max+1)]
            #cocotb.log.info(f"[REGs] \tmodel = {model.registers}, \n \tdut   = {dut_values}")

            cocotb.log.info(f"exp_rdata = {exp_rdata}, exp_hmac_valid = {exp_hmac_valid}")
            cocotb.log.info(f"dut_rdata = {dut_rdata}, dut_hmac_valid = {dut_hmac_valid} \n")

        assert dut_rdata == exp_rdata
        assert dut_hmac_valid == exp_hmac_valid            

    cocotb.log.warning(f"Stimulating to access all states of FSM")
    for j in range(2):
        await hrs_lb.reset_dut(dut.rst_n)
        await RisingEdge(dut.clk)
        for i in range(20):
           if i < 2:
               write = 1
           else:
               write = 0
           read = not write
           data = 0
           if j == 0:
               data = data_max
           dut.write_en.value = write
           dut.read_en.value  = read
           dut.wdata.value    = data               
           await RisingEdge(dut.clk)
           # Track the current state of the DUT
           current_state = dut.current_state.value.integer
           visited_states.add(current_state)            
           if debug:
               cocotb.log.info(f"[STATE] dut = {dut.current_state.value.integer} ")
            
    cocotb.log.warning(f"ASSERTION to check if all states were visited")
    # Assert that all states (0 to 6) have been visited
    expected_states = set(range(7))  # {0, 1, 2, 3, 4, 5, 6}
    assert visited_states == expected_states, f"Not all states were visited: {visited_states}"        

@cocotb.test()
async def test_hmac_reg_interface_validate_data_and_key(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    debug = 1

    DATA_WIDTH = dut.DATA_WIDTH.value.integer
    ADDR_WIDTH = dut.ADDR_WIDTH.value.integer

    model = hrs_lb.HMACRegInterface(DATA_WIDTH, ADDR_WIDTH)

    # Initialize DUT
    await hrs_lb.dut_init(dut)
    # Apply reset
    await hrs_lb.reset_dut(dut.rst_n)
    await RisingEdge(dut.clk)
    model.reset()

    # Calculate min and max values for data and coefficients
    data_min = 0
    data_max = int(2**DATA_WIDTH - 1)
    addr_min = 0
    addr_max = int(2**ADDR_WIDTH - 1)

    # Create address vector
    addr_vector = [0] * 4 + [1] * 4 + [0] * 4 + [1] * 4
    cocotb.log.warning(f"Running WRITE OPERATION {len(addr_vector)} cycles")
    loop_size = len(addr_vector)
    for i, addr in enumerate(addr_vector):
        if i >= loop_size/2:
           write = 0
        else:
           write = 1
        read = not write
        data = random.randint(data_min, data_max-1)
        wait_en = 0
        dut.write_en.value = write
        dut.read_en.value = read
        dut.addr.value = addr
        dut.wdata.value = data
        dut.i_wait_en.value = wait_en

        await RisingEdge(dut.clk)
        exp_rdata, exp_hmac_valid = model.compute(write, read, wait_en, addr, data)
        dut_rdata = dut.rdata.value.integer
        dut_hmac_valid = dut.hmac_valid.value.integer
        current_state = dut.current_state.value.integer
        key_error = dut.hmac_key_error.value.integer
        model_key_error = model.hmac_key_error

        if debug:
            cocotb.log.info(f"Test cycle number : {i}")
            cocotb.log.info(f"write_en = {write}, read_en = {read}, addr = {addr}, data = {data}")
            cocotb.log.info(f"[STATE] model = {model.current_state}, dut = {current_state}")
            cocotb.log.info(f"[PROC DATA] model = {model.processed_data}, dut = {dut.xor_data.value.integer} ")

            #dut_values = [dut.registers.value[i].to_unsigned() for i in range(addr_max+1)]
            #cocotb.log.info(f"[REGs] \tmodel = {model.registers}, \n \tdut   = {dut_values}")
            cocotb.log.warning(f'hmac_key  = {dut.hmac_key.value.integer}')
            cocotb.log.warning(f'hmac_data = {dut.hmac_data.value.integer}')

            cocotb.log.warning(f'model_hmac_key_error = {model.hmac_key_error}')
            cocotb.log.warning(f'dut_hmac_key_error   = {dut.hmac_key_error.value.integer}')
                               

            cocotb.log.info(f"exp_rdata = {exp_rdata}, exp_hmac_valid = {exp_hmac_valid}")
            cocotb.log.info(f"dut_rdata = {dut_rdata}, dut_hmac_valid = {dut_hmac_valid} \n")

        assert key_error == model_key_error
        assert dut_rdata == exp_rdata
        assert dut_hmac_valid == exp_hmac_valid