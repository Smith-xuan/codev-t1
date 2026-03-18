import os
from cocotb_tools.runner import get_runner

verilog_sources = os.getenv("VERILOG_SOURCES", "").split()
toplevel_lang   = os.getenv("TOPLEVEL_LANG", "verilog")
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL", "axis_mux")
module          = os.getenv("MODULE", "test_axis_mux")
wave            = os.getenv("WAVE", "True")

# Read environment variables for parameters
param_axis_data_width  = os.getenv("PARAM_C_AXIS_DATA_WIDTH",  "32")
param_axis_tuser_width = os.getenv("PARAM_C_AXIS_TUSER_WIDTH", "4")
param_axis_tid_width   = os.getenv("PARAM_C_AXIS_TID_WIDTH",   "2")
param_axis_tdest_width = os.getenv("PARAM_C_AXIS_TDEST_WIDTH", "2")
param_num_inputs       = os.getenv("PARAM_NUM_INPUTS",         "4")

def test_runner():
    runner = get_runner(sim)

    parameters = {
        "C_AXIS_DATA_WIDTH":  param_axis_data_width,
        "C_AXIS_TUSER_WIDTH": param_axis_tuser_width,
        "C_AXIS_TID_WIDTH":   param_axis_tid_width,
        "C_AXIS_TDEST_WIDTH": param_axis_tdest_width,
        "NUM_INPUTS":         param_num_inputs
    }

    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters,
        always=True,
        clean=True,
        waves=(wave.lower() == "true"),
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="build.log"
    )

    runner.test(
        hdl_toplevel=toplevel,
        test_module=module,
        waves=(wave.lower() == "true")
    )

if __name__ == "__main__":
    test_runner()
