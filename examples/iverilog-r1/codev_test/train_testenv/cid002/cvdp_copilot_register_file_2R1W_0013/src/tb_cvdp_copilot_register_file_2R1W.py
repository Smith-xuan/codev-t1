import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import harness_library as hrs_lb

# ----------------------------------------
# - Register File 2R1W Test
# ----------------------------------------

async def reset_dut(dut, duration_ns=10):
    """
    Reset the DUT by setting resetn low for a specified duration,
    then setting it high to deactivate reset.

    During reset, ensure outputs are zero.
    """
    dut.resetn.value = 0  # Active-low reset
    await Timer(duration_ns, units="ns")
    dut.resetn.value = 1  # Deactivate reset
    await Timer(duration_ns, units="ns")
    dut._log.debug("Reset complete")


@cocotb.test()
async def verify_register_file(dut):
    """
    Test register file functionality including:
    - Write and read operations
    - Collision detection
    - Clock gating scenarios
    """

    # Start the clock with a 10ns period
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Initialize DUT inputs using helper function from the harness library
    await hrs_lb.dut_init(dut)

    # Apply reset to DUT
    await reset_dut(dut)

    # Test 1: Simple write and read without collision
    cocotb.log.info("Test 1: Simple write and read without collision")
    await write_data(dut, 10, 0xA5A5A5A5)  # Write to address 10
    await read_data(dut, 10, 0, 0xA5A5A5A5, 0, collision_expected=False)  # No collision expected

    # Test 2: Collision detection - read and write to the same address
    cocotb.log.info("Test 2: Collision detection - simultaneous read/write to same address")
    await write_data(dut, 15, 0x5A5A5A5A)  # Write to address 15
    
    # Set up for collision detection
    dut.rad1.value = 15
    dut.ren1.value = 1
    dut.wad1.value = 15
    dut.wen1.value = 1
    
    # Hold the signals steady for an extra clock cycle
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  # Allow time for collision to be detected

    # Log and assert collision status
    dut._log.info(f"Collision Test: rad1={dut.rad1.value}, wad1={dut.wad1.value}, ren1={dut.ren1.value}, wen1={dut.wen1.value}, collision={dut.collision.value}")
    assert dut.collision.value == 1, "FAIL: Expected collision on read/write to address 15"
    
    # Reset ren1 and wen1 after collision detection
    dut.ren1.value = 0
    dut.wen1.value = 0
    await Timer(10, units="ns")

    # Test 3: Collision detection - simultaneous reads from same address
    cocotb.log.info("Test 3: Collision detection - simultaneous reads from same address")
    await write_data(dut, 20, 0x12345678)  # Write to address 20
    await check_collision(dut, rad1=20, rad2=20, collision_expected=True)

    # Test 4: Clock gating - No operations active
    cocotb.log.info("Test 4: Clock gating - No operations active")
    await Timer(20, units="ns")  # Observe idle period with no active signals

    # Test 5: Clock gating - alternating enable signals
    cocotb.log.info("Test 5: Clock gating - Alternating enable signals")
    await write_data(dut, 25, 0xDEADBEEF)  # Write to address 25
    await read_data(dut, 25, 26, 0xDEADBEEF, 0x0, collision_expected=False)  # No collision expected

    # Test 6: Write and read from different addresses without collision
    cocotb.log.info("Test 6: Write and simultaneous read from different addresses without collision")
    await write_data(dut, 12, 0xCAFEBABE)  # Write to address 12
    await read_data(dut, 12, 13, 0xCAFEBABE, 0x0, collision_expected=False)

    # Test 7: Reset and verify cleared register and collision status
    cocotb.log.info("Test 7: Verify reset clears registers and collision")
    await reset_dut(dut)
    await read_data(dut, 10, 12, 0x0, 0x0, collision_expected=False)  # All cleared after reset


async def write_data(dut, address, data):
    dut.wad1.value = address
    dut.din.value = data
    dut.wen1.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  # Hold `wen1` active for an extra cycle
    dut.wen1.value = 0
    await Timer(10, units="ns")
    dut._log.info(f"Write: wad1={address}, din={data}, wen1={dut.wen1.value}")



async def read_data(dut, rad1, rad2, expected_data1, expected_data2, collision_expected):
    dut.rad1.value = rad1
    dut.rad2.value = rad2
    dut.ren1.value = 1
    dut.ren2.value = 1
    await RisingEdge(dut.clk)  # Wait for the read operation to latch
    await RisingEdge(dut.clk)  # Wait for the read operation to latch
    await RisingEdge(dut.clk)  # Wait for the read operation to latch    
    # Small delay to ensure the DUT updates the output signals
    #await Timer(1, units="ns")
    
    # Logging intermediate values for debugging
    dut._log.info(f"Reading: dout1={dut.dout1.value}, dout2={dut.dout2.value}, collision={dut.collision.value}")

    assert dut.dout1.value == expected_data1, f"FAIL: dout1={dut.dout1.value} expected={expected_data1}"
    assert dut.dout2.value == expected_data2, f"FAIL: dout2={dut.dout2.value} expected={expected_data2}"
    assert dut.collision.value == collision_expected, f"FAIL: collision={dut.collision.value} expected={collision_expected}"

    dut.ren1.value = 0
    dut.ren2.value = 0
    await Timer(10, units="ns")



async def check_collision(dut, rad1, rad2, collision_expected):
    """
    Check for collision between two reads from the same address.
    """
    dut.rad1.value = rad1
    dut.rad2.value = rad2
    dut.ren1.value = 1
    dut.ren2.value = 1
    
    # Hold the read enable signals steady for an extra clock cycle
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  # Allow time for collision detection
    
    # Log and verify the collision status
    dut._log.info(f"Collision Check: rad1={rad1}, rad2={rad2}, ren1={dut.ren1.value}, ren2={dut.ren2.value}, collision={dut.collision.value}")
    assert dut.collision.value == collision_expected, f"FAIL: collision={dut.collision.value} expected={collision_expected}"

    # Reset ren1 and ren2 after collision check
    dut.ren1.value = 0
    dut.ren2.value = 0
    await Timer(10, units="ns")

