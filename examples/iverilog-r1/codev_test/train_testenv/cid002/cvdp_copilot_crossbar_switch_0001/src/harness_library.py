
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def reset_dut(reset, duration_ns = 10):
    # Restart Interface
    reset.value = 1
    await Timer(duration_ns, units="ns")
    reset.value = 0
    await Timer(duration_ns, units="ns")
    reset.value = 1
    await Timer(duration_ns, units='ns')
    reset._log.debug("Reset complete")


async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

async def crossbar_switch_4x4 (input_port_list, input_port_valids, DATA_WIDTH):
    output_port_list = [0, 0, 0, 0]
    output_port_valids = [0, 0, 0, 0]
    index_of_input_valid = input_port_valids.index(1)
    counter = 0
    MAX_VALUE = (1 << DATA_WIDTH) - 1  # Creates a mask of lower DATA_WIDTH bits
    
    for valid_in in input_port_valids:
        if valid_in == 1 :
            expected_dest_id = input_port_list[counter] >> DATA_WIDTH
            output_port_list [expected_dest_id] = input_port_list [counter] & MAX_VALUE
            output_port_valids [expected_dest_id] = 1
            break  # Exit the loop on the first valid input
        counter += 1

    return output_port_list, output_port_valids, expected_dest_id
    
    
     
        
    