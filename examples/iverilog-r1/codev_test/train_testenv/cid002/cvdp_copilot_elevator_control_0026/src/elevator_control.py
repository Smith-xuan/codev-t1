import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge

FLOOR = cocotb.plusargs.get("N")

# Helper function to reset DUT
async def reset_dut(dut, duration_ns):
    dut.reset.value = 1
    await Timer(duration_ns, units="ns")
    dut.reset.value = 0
    await RisingEdge(dut.clk)

# Helper function to trigger a floor request
async def request_floor(dut, floor):
    #current_requests = int(dut.call_requests.value)  # Convert LogicArray to integer
    dut.call_requests.value =  (1 << floor)  # Perform bitwise OR
    await RisingEdge(dut.clk)
    dut.call_requests.value =  0

# Helper function to clear call requests
async def clear_requests(dut):
    dut.call_requests.value = 0
    await RisingEdge(dut.clk)

#Helper function to wait for door close
async def wait_door_close(dut):
    # Wait until the door closes
    dut._log.info("Waiting for the door to close")
    while dut.door_open.value == 1:
        await RisingEdge(dut.clk)

# Helper function to check seven-segment display output for all places
async def check_seven_segment(dut, expected_floor):
    # Floor-to-segment mappings
    floor_to_seg_map = {
        0: 0b1111110,  # 0
        1: 0b0110000,  # 1
        2: 0b1101101,  # 2
        3: 0b1111001,  # 3
        4: 0b0110011,  # 4
        5: 0b1011011,  # 5
        6: 0b1011111,  # 6
        7: 0b1110000,  # 7
        8: 0b1111111,  # 8
        9: 0b1111011   # 9
    }

    # Convert the expected floor to its BCD representation
    expected_one = expected_floor % 10
    expected_ten = (expected_floor // 10) % 10
    expected_hundred = (expected_floor // 100) % 10

    # Check one's place
    await RisingEdge(dut.clk)

    while dut.seven_seg_out_anode.value != 0b1110:
        await RisingEdge(dut.clk)
    if dut.seven_seg_out_anode.value == 0b1110:
        assert int(dut.seven_seg_out.value) == floor_to_seg_map[expected_one], \
            f"One's place mismatch: Expected {bin(floor_to_seg_map[expected_one])}, got {bin(int(dut.seven_seg_out.value))}"
        dut._log.info(f"One's place matched: {expected_one}")

    # Check ten's place
    await RisingEdge(dut.clk)
    while dut.seven_seg_out_anode.value != 0b1101:
        await RisingEdge(dut.clk)
    if dut.seven_seg_out_anode.value == 0b1101:
        assert int(dut.seven_seg_out.value) == floor_to_seg_map[expected_ten], \
            f"Ten's place mismatch: Expected {bin(floor_to_seg_map[expected_ten])}, got {bin(int(dut.seven_seg_out.value))}"
        dut._log.info(f"Ten's place matched: {expected_ten}")

    # Check hundred's place
    await RisingEdge(dut.clk)
    while dut.seven_seg_out_anode.value != 0b1011:
        await RisingEdge(dut.clk)
    if dut.seven_seg_out_anode.value == 0b1011:
        assert int(dut.seven_seg_out.value) == floor_to_seg_map[expected_hundred], \
            f"Hundred's place mismatch: Expected {bin(floor_to_seg_map[expected_hundred])}, got {bin(int(dut.seven_seg_out.value))}"
        dut._log.info(f"Hundred's place matched: {expected_hundred}")

    dut._log.info("All digit places matched successfully")



# Test case 1: Single floor request
async def test_case_1(dut):
    """Test case 1: Single floor request"""

    # Request floor 3 and check if the elevator reaches it
    dut._log.info("Requesting floor 3")
    await request_floor(dut, 3)

    #print("A Current Floor", dut.current_floor.value)

    # Wait and check if the elevator reaches floor 3
    while dut.current_floor.value != 3:
        await RisingEdge(dut.clk)
        #print("Current Floor", dut.current_floor.value)
    await RisingEdge(dut.clk)
    await Timer(30, units="ns")
    
    assert dut.door_open.value == 1, "Door did not open at requested floor"
    await check_seven_segment(dut, 3)

    dut._log.info("Elevator reached floor 3 successfully")

    await wait_door_close(dut)

    dut._log.info("Door closed successfully after reaching floor")

# Test case 2: Multiple floor requests
async def test_case_2(dut):
    """Test case 2: Multiple floor requests"""

    FLOOR_SIZE = int(FLOOR)
    floor_list = []
    if(FLOOR_SIZE == 12):
        dut._log.info("Requesting floor 11")
        floor_list = [11]
        # Request floors 11
        await request_floor(dut, 11)
    elif(FLOOR_SIZE == 13 or FLOOR_SIZE == 14 ):
        dut._log.info("Requesting floor 12")
        floor_list = [12]
        # Request floors 11
        await request_floor(dut, 12)
    elif(FLOOR_SIZE == 24):
        dut._log.info("Requesting floor 19")
        floor_list = [19]
        # Request floors 11
        await request_floor(dut, 19)

    # Check if the elevator serves requests in sequence
    for expected_floor in floor_list:
        while dut.current_floor.value != expected_floor:
            await RisingEdge(dut.clk)
        await Timer(30, units="ns")
        assert dut.door_open.value == 1, f"Door did not open at floor {expected_floor}"
        await Timer(40, units="ns")  # Simulate door open delay
        #print(expected_floor, "door value: ", dut.door_open.value)
        await check_seven_segment(dut, expected_floor)
        dut._log.info(f"Elevator reached floor {expected_floor}")

    dut._log.info("Elevator served multiple requests successfully")


@cocotb.test()
async def test_elevator_control_system(dut):
    """Main test function for elevator control system"""

    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Initialize all signals to known values
    dut.reset.value = 0
    dut.call_requests.value = 0
    dut.emergency_stop.value = 0

    FLOOR_SIZE = int(FLOOR) - 1
    print("System FLOOR Size: 0 to", FLOOR_SIZE)

    ## Apply reset
    await reset_dut(dut, 30)

    ## Run test cases
    dut._log.info("Test case 1")
    await test_case_1(dut)
    await Timer(20, units="ns")  # Wait before next test

    dut._log.info("Test case 2")
    await reset_dut(dut, 30)
    await test_case_2(dut)
    await Timer(20, units="ns")

