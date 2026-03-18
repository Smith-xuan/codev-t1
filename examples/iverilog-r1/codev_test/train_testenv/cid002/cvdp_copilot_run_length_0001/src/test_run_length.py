import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge,FallingEdge,Timer
import harness_library as hrs_lb
import random


@cocotb.test()
#Cocotb test for the run_length module.
async def test_run_length(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Initialize the DUT signals with default 0
    await hrs_lb.dut_init(dut)

    # Reset the DUT rst_n signal, active=False)
    dut.data_in.value = 0

    await hrs_lb.reset_dut(dut.reset_n, duration_ns=5, active=False)
    data_wd = int(dut.DATA_WIDTH.value)
    await FallingEdge (dut.clk)
    data_sequence = [1]*data_wd
    dut._log.info(f"DRIVE ALL ones, DATA_WIDTH = {data_wd}")
    await drive_input(dut, data_sequence,data_wd)
    #await check_outputs(dut, data_sequence,data_wd)
    assert dut.run_value.value == data_wd, f"[ERROR] run_value is not macthed after continous ones's: {dut.run_value.value}"
    assert dut.valid.value == 1, f"[ERROR] valid is not macthed after continous ones's: {dut.valid.value}"
    assert dut.data_out.value == 1, f"[ERROR] data_out is not macthed after continous one's: {dut.data_out.value}"
    dut.data_in.value = 0
    await hrs_lb.reset_dut(dut.reset_n, duration_ns=5, active=False)
    dut._log.info(f"APPLY on the fly reset")
    if dut.reset_n.value == 0:
        assert dut.run_value.value ==  0, f"[ERROR] run_value is not zero after reset: {dut.run_value.value}"
        assert dut.valid.value == 0, f"[ERROR] valid is not zero after reset: {dut.valid.value}"
        assert dut.data_out.value == 0, f"[ERROR] data_out is not zero after reset: {dut.data_out.value}"
    dut._log.info(f"After on the fly reset :: data_out = {dut.data_out.value}, valid = {dut.valid.value}, run_value = {dut.run_value.value}")
    data_sequence = [0]*data_wd
    dut._log.info(f"DRIVE ALL zeros, DATA_WIDTH = {data_wd}")
    await drive_input(dut, data_sequence,data_wd)
    #await check_outputs(dut, data_sequence,data_wd)
    assert dut.run_value.value == data_wd, f"[ERROR] run_value is not macthed after continous zero's: {dut.run_value.value}"
    assert dut.valid.value == 1, f"[ERROR] valid is not macthed after continous zero's: {dut.valid.value}"
    assert dut.data_out.value == 0, f"[ERROR] data_out is not macthed after continous zero's: {dut.data_out.value}"
    data_sequence = [random.randint(0, 1) for i in range(data_wd)]
    dut._log.info(f"DRIVE random inputs, DATA_WIDTH = {data_wd}")
    await drive_input(dut, data_sequence,data_wd)
    await FallingEdge(dut.valid)
    await check_outputs(dut, data_sequence,data_wd)
     
async def drive_input(dut, data_sequence,data_wd):
    prev_data = None
    for data_in in data_sequence:
        dut.data_in.value = data_in
        await FallingEdge(dut.clk)
        dut._log.info(f"RANDOM_INPUT :: DATA_WIDTH = {int(data_wd)},data_in = {dut.data_in.value}, data_out = {dut.data_out.value}, run_value = {dut.run_value.value}, valid = {dut.valid.value}")
    await FallingEdge(dut.clk)
    dut._log.info(f"check :: data_in = {dut.data_in.value}, data_out = {dut.data_out.value}, run_value = {dut.run_value.value}, valid = {dut.valid.value}")
async def check_outputs(dut, data_sequence, data_wd):
    run_length = 0
    prev_data = None
    expected_valid = 0

    for data_in in data_sequence:
        actual_run_value = int(dut.run_value.value)
        actual_data_out = int(dut.data_out.value)
        actual_valid = int(dut.valid.value)
        # Check if we are continuing the same run or starting a new run
        if data_in == prev_data:
            run_length += 1
            # Saturate if run_length exceeds maximum count for DATA_WIDTH
            if run_length >= (data_wd):
                run_length = (data_wd) - 1
    

        else:
            # Check outputs when the run ends (only valid if not the first input)
            if prev_data is not None:
                await Timer(10, units="ns")
                if prev_data == data_in:
                    expected_valid = 0
                else:
                    expected_valid = 1
                
                if prev_data == data_in:
                    prev_data = 0
                else:
                    if data_in == 1:
                        prev_data = 0
                    else:
                        prev_data = 1
                if dut.valid.value == 1:
                    assert actual_data_out == prev_data, f"DATA_OUT failed: expected {prev_data}, got {actual_data_out}"
                    assert actual_run_value == run_length, f"RUN_VALUE failed: expected {run_length}, got {actual_run_value}"

            # Reset for new run
            run_length = 1
            expected_valid = 0  # New run should reset valid

        # Update previous data
        prev_data = data_in

        if prev_data == data_in:
            prev_data = 0
        else:
            if data_in == 1:
                prev_data = 0
            else:
                prev_data = 1



    # Final check for the last run
    await Timer(10, units="ns")
    if prev_data is not None:
        await Timer(5, units="ns")
        assert int(dut.valid.value) == expected_valid, f"VALID failed for final value: expected {expected_valid}, got {int(dut.valid.value)}"
        if dut.valid.value == 1:
            assert int(dut.run_value.value) == run_length, f"RUN_VALUE failed for final value: expected {run_length}, got {int(dut.run_value)}"
            assert int(dut.data_out.value) == prev_data, f"DATA_OUT failed for final value: expected {prev_data}, got {int(dut.data_out)}"


