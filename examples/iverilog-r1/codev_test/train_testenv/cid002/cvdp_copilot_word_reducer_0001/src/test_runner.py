import os
from cocotb_tools.runner import get_runner
import pytest

verilog_sources = os.getenv("VERILOG_SOURCES").split()
sim             = os.getenv("SIM", "icarus")
toplevel        = os.getenv("TOPLEVEL")
module          = os.getenv("MODULE")
wave            = bool(os.getenv("WAVE"))

# Map operation names to 3-bit codes
REDUCTION_OP_CODES = {
    "AND":  0b000,
    "OR":   0b001,
    "XOR":  0b010,
    "NAND": 0b011,
    "NOR":  0b100,
    "XNOR": 0b101,
    "default": 0b110 
}

def runner(DATA_WIDTH: int = 4, DATA_COUNT: int = 4, REDUCTION_OP: str = "AND"):
    reduction_op_code = REDUCTION_OP_CODES[REDUCTION_OP]

    parameter = {
        "DATA_WIDTH": DATA_WIDTH,
        "DATA_COUNT": DATA_COUNT,
        "REDUCTION_OP": reduction_op_code
    }
  
    print(f"[INFO] Testing with REDUCTION_OP={REDUCTION_OP} ({reduction_op_code}), DATA_WIDTH={DATA_WIDTH}, DATA_COUNT={DATA_COUNT}")
    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameter,
        always=True,
        clean=True,
        waves=wave,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="sim.log"
    )
    runner.test(hdl_toplevel=toplevel, test_module=module, waves=wave)


@pytest.mark.parametrize("test", range(1))
@pytest.mark.parametrize("REDUCTION_OP", ["AND", "OR", "XOR", "NAND", "NOR", "XNOR", "default"])
@pytest.mark.parametrize("DATA_WIDTH", [1, 10, 3])
@pytest.mark.parametrize("DATA_COUNT", [2, 3, 8])
def test_data_reduction(test, DATA_COUNT, DATA_WIDTH, REDUCTION_OP):
    runner(DATA_WIDTH=DATA_WIDTH, DATA_COUNT=DATA_COUNT, REDUCTION_OP=REDUCTION_OP)
