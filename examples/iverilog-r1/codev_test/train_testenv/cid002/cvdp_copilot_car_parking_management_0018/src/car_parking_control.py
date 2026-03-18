import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge


TOTAL_SPACES = int(cocotb.plusargs.get("TOTAL_SPACES", 12))
PARKING_FEE_VALUE = int(cocotb.plusargs.get("PARKING_FEE_VALUE", 50))
MAX_DAILY_FEE = int(cocotb.plusargs.get("MAX_DAILY_FEE", 500))

# Helper function to reset DUT
async def reset_dut(dut, duration_ns=20):
    """Reset DUT"""
    dut.reset.value = 1
    await Timer(duration_ns, units="ns")
    dut.reset.value = 0
    await RisingEdge(dut.clk)

# Helper function to trigger vehicle entry
async def trigger_entry(dut, current_slot, current_time):
    """Simulate vehicle entry"""
    dut.vehicle_entry_sensor.value = 1
    dut.current_slot.value = current_slot
    dut.current_time.value = current_time
    await Timer(10, units="ns")
    dut.vehicle_entry_sensor.value = 0

# Helper function to trigger vehicle exit
async def trigger_exit(dut, current_slot, current_time):
    """Simulate vehicle exit"""
    dut.vehicle_exit_sensor.value = 1
    dut.current_slot.value = current_slot
    dut.current_time.value = current_time
    await Timer(10, units="ns")
    dut.vehicle_exit_sensor.value = 0

async def validate_fee(dut, expected_fee):
    """Validate the calculated parking fee"""
    await Timer(10, units="ns")
    dut._log.info(f"fee_ready: {int(dut.fee_ready.value)}, parking_fee: {int(dut.parking_fee.value)}")
    assert dut.fee_ready.value == 1, "Fee not marked as ready"
    assert dut.parking_fee.value == expected_fee, \
        f"Parking fee mismatch: Expected {expected_fee}, Got {int(dut.parking_fee.value)}"

async def validate_qr_code(dut, expected_fee, current_slot, time_spent):
    """Validate the QR code contents"""
    expected_qr_code = (current_slot << 112) | (expected_fee << 96) | ((time_spent & 0xFFFF) << 80)
    observed_qr_code = int(dut.qr_code.value)
    assert observed_qr_code == expected_qr_code, \
        f"QR code mismatch: Expected {hex(expected_qr_code)}, Got {hex(observed_qr_code)}"
    dut._log.info(f"Validated QR code: {hex(expected_qr_code)}")

# Test case: QR code generation and dynamic fee calculation
async def test_qr_code_and_dynamic_fee(dut):
    """Test QR code generation and dynamic fee adjustment"""
    dut._log.info("Testing QR code generation and dynamic fees")

    # Simulate entry during peak hours (e.g., 9 AM, fee = double)
    peak_hour = 9
    await trigger_entry(dut, current_slot=0, current_time=0)
    dut.hour_of_day.value = peak_hour
    await Timer(30, units="ns")

    # Simulate exit after 1 hour during peak hours
    await trigger_exit(dut, current_slot=0, current_time=3600)
    expected_fee = 2 * PARKING_FEE_VALUE  # Double fee for peak hours
    await validate_fee(dut, expected_fee=expected_fee)
    await validate_qr_code(dut, expected_fee=expected_fee, current_slot=0, time_spent=3600)

    # Simulate entry during off-peak hours (e.g., 11 PM, fee = normal)
    off_peak_hour = 23
    await trigger_entry(dut, current_slot=1, current_time=0)
    dut.hour_of_day.value = off_peak_hour
    await Timer(30, units="ns")

    # Simulate exit after 1 hour during off-peak hours
    await trigger_exit(dut, current_slot=1, current_time=3600)
    expected_fee = PARKING_FEE_VALUE  # Normal fee for off-peak hours
    await validate_fee(dut, expected_fee=expected_fee)
    await validate_qr_code(dut, expected_fee=expected_fee, current_slot=1, time_spent=3600)


    # Scenario 3: Mixed hours, fee exceeds max daily cap
    await trigger_entry(dut, current_slot=2, current_time=0)
    dut.hour_of_day.value = 7  # Entry during off-peak
    await Timer(30, units="ns")
    dut.hour_of_day.value = 10  # Exit during peak

    # Simulate exit after 15 hours (mixed hours)
    await trigger_exit(dut, current_slot=2, current_time=54000)  # 15 hours
    expected_fee = MAX_DAILY_FEE  # Fee capped at max daily value
    await validate_fee(dut, expected_fee=expected_fee)
    await validate_qr_code(dut, expected_fee=expected_fee, current_slot=2, time_spent=54000)


def seven_segment_encoding(digit):
    """Returns the seven-segment encoding for a given digit (0-9)"""
    encoding_map = {
        0: 0b1111110,
        1: 0b0110000,
        2: 0b1101101,
        3: 0b1111001,
        4: 0b0110011,
        5: 0b1011011,
        6: 0b1011111,
        7: 0b1110000,
        8: 0b1111111,
        9: 0b1111011,
    }
    return encoding_map.get(digit, 0b0000000)  # Default to blank display

async def validate_seven_segment(dut, available_spaces, count_car):
    """
    Validate seven-segment display outputs for available spaces and count car.
    """
    # Calculate tens and units for available spaces
    available_tens = available_spaces // 10
    available_units = available_spaces % 10

    # Calculate tens and units for count car
    count_tens = count_car // 10
    count_units = count_car % 10

    # Validate seven-segment display for available spaces
    assert int(dut.seven_seg_display_available_tens.value) == seven_segment_encoding(available_tens), \
        f"Available Spaces Tens Mismatch: Expected {bin(seven_segment_encoding(available_tens))}, Got {bin(int(dut.seven_seg_display_available_tens.value))}"
    assert int(dut.seven_seg_display_available_units.value) == seven_segment_encoding(available_units), \
        f"Available Spaces Units Mismatch: Expected {bin(seven_segment_encoding(available_units))}, Got {bin(int(dut.seven_seg_display_available_units.value))}"

    # Validate seven-segment display for count car
    assert int(dut.seven_seg_display_count_tens.value) == seven_segment_encoding(count_tens), \
        f"Count Car Tens Mismatch: Expected {bin(seven_segment_encoding(count_tens))}, Got {bin(int(dut.seven_seg_display_count_tens.value))}"
    assert int(dut.seven_seg_display_count_units.value) == seven_segment_encoding(count_units), \
        f"Count Car Units Mismatch: Expected {bin(seven_segment_encoding(count_units))}, Got {bin(int(dut.seven_seg_display_count_units.value))}"

    dut._log.info("Seven-segment display validated successfully")

# Test case: Billing for parking duration
async def test_billing(dut):
    """Test case: Verify parking fee calculation"""

    dut._log.info("Simulating vehicle entry and exit with billing")

    # Simulate entry at slot 0 and time 0 seconds
    await trigger_entry(dut, current_slot=0, current_time=0)
    await Timer(30, units="ns")
    assert dut.count_car.value == 1, "Count car did not increment as expected"
    assert dut.available_spaces.value == (TOTAL_SPACES - 1), "Available spaces did not decrement as expected"

    # Simulate exit at slot 0 and time 3600 seconds (1 hour)
    await trigger_exit(dut, current_slot=0, current_time=3600)
    #await Timer(10, units="ns")    
    await validate_fee(dut, expected_fee=50)  # 50 units per hour fee

    # Simulate entry and exit with fractional hours
    await trigger_entry(dut, current_slot=1, current_time=3600)
    await Timer(30, units="ns")
    await trigger_exit(dut, current_slot=1, current_time=9000)  # 1.5 hours
    await validate_fee(dut, expected_fee=100)  # Rounded to 2 hours

# Test case 1: Basic entry
async def test_case_1(dut):
    """Test case 1: Single vehicle entry"""

    dut._log.info("Simulating single vehicle entry")
    await trigger_entry(dut)

    # Wait for state to update
    await Timer(30, units="ns")
    assert dut.count_car.value == 1, "Count car did not increment as expected"
    assert dut.available_spaces.value == (TOTAL_SPACES - 1), "Available spaces did not decrement as expected"

    # Validate seven-segment display
    await validate_seven_segment(dut, available_spaces=(TOTAL_SPACES - 1), count_car=1)

    #print(hex(int(dut.seven_seg_display_available_tens.value)))
    # Check seven-segment display
    #check_seven_segment(dut, available_spaces=(TOTAL_SPACES - 1), count_car=1)

# Test case 2: Basic exit
async def test_case_2(dut):
    """Test case 2: Single vehicle exit"""

    dut._log.info("Simulating single vehicle exit")
    await trigger_exit(dut)

    # Wait for state to update
    await Timer(20, units="ns")
    assert dut.count_car.value == 0, "Count car did not decrement as expected"
    assert dut.available_spaces.value == TOTAL_SPACES, "Available spaces did not increment as expected"

    # Validate seven-segment display
    await validate_seven_segment(dut, available_spaces=TOTAL_SPACES, count_car=0)


# Test case 3: Parking full
async def test_case_3(dut):
    """Test case 3: Simulate parking full"""

    dut._log.info("Simulating parking full scenario")
    for _ in range(TOTAL_SPACES):
        await trigger_entry(dut)
        await Timer(20, units="ns")
        
    # Wait for state to update
    assert dut.led_status.value == 0, "LED status did not indicate parking full"
    assert dut.available_spaces.value == 0, "Available spaces did not reach 0"
    assert dut.count_car.value == TOTAL_SPACES, "Car count did not reach total spaces"

    # Attempt another entry
    await trigger_entry(dut)
    await Timer(20, units="ns")
    assert dut.count_car.value == TOTAL_SPACES, "Car count should not exceed total spaces"

    # Validate seven-segment display
    await validate_seven_segment(dut, available_spaces=0, count_car=TOTAL_SPACES)

# Test case 4: Reset operation
async def test_case_4(dut):
    """Test case 4: Reset during operation"""

    dut._log.info("Simulating reset during operation")
    await trigger_entry(dut)
    await Timer(20, units="ns")
    await reset_dut(dut)

    # Validate reset state
    assert dut.count_car.value == 0, "Count car did not reset to 0"
    assert dut.available_spaces.value == TOTAL_SPACES, "Available spaces did not reset to total"

@cocotb.test()
async def test_car_parking_system(dut):
    """Main test function for Car Parking System"""

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.reset.value = 1
    dut.vehicle_exit_sensor.value = 0
    dut.vehicle_entry_sensor.value = 0
    dut.current_slot.value = 0
    dut.current_time.value = 0
    dut.hour_of_day.value = 0

    # Apply reset
    await reset_dut(dut, duration_ns=30)
    await Timer(40, units="ns")
    
    # Run test cases
    await test_qr_code_and_dynamic_fee(dut)
