import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

START_CHAR = 0xFB
END_CHAR   = 0xFD

@cocotb.test()
async def pkt_detector_test(dut):
    """
    Cocotb test that replicates the functionality 
    from the SystemVerilog testbench.
    """

    # ---------------------------
    # 1) Setup & Reset
    # ---------------------------
    CLK_PER = 10  # ns
    cocotb.start_soon(Clock(dut.clk, CLK_PER, units="ns").start())

    # Initialize signals
    dut.reset.value = 0
    dut.data_in.value = 0
    dut.data_k_flag.value = 0

    # Deassert reset after 3 clock periods
    await Timer(3 * CLK_PER, units="ns")
    dut.reset.value = 1

    # Wait for a rising edge after reset is high
    await RisingEdge(dut.clk)

    # Track errors
    errors = 0

    # ---------------------------
    # 2) Utility Routines
    # ---------------------------

    async def drive_packet(start_char, end_char, packet_type):
        """
        Send exactly 20 bytes:
        - 1st byte = start_char (with data_k_flag=1)
        - 3rd or 4th byte = packet_type
        - 20th byte = end_char (with data_k_flag=1)
        Everything else data_k_flag=0
        """
        # Prepare 20 bytes
        packet = [random.randint(0, 255) for _ in range(20)]
        packet[0]  = start_char
        packet[3]  = packet_type
        packet[19] = end_char

        # Drive each byte at posedge, hold for 1 clock cycle
        for i in range(20):
            await RisingEdge(dut.clk)
            dut.data_in.value = packet[i]
            if (i == 0 and packet[i] == start_char) or (i == 19 and packet[i] == end_char):
                dut.data_k_flag.value = 1
            else:
                dut.data_k_flag.value = 0

        # Idle for 1 clock
        await RisingEdge(dut.clk)
        dut.data_in.value = 0
        dut.data_k_flag.value = 0

    async def check_no_increment(exp_count):
        """
        After sending an invalid packet, confirm pkt_count
        stays at exp_count and all detection signals are 0.
        """
        # Let the DUT process for 2 cycles
        for _ in range(2):
            await RisingEdge(dut.clk)

        got_count = int(dut.pkt_count.value)
        if got_count != exp_count:
            dut._log.error(f"ERROR: Packet count mismatch! Got={got_count}, Exp={exp_count}")
            nonlocal errors
            errors += 1

        # Check that detection signals remain deasserted
        signals = {
            "mem_read_detected":        int(dut.mem_read_detected.value),
            "mem_write_detected":       int(dut.mem_write_detected.value),
            "io_read_detected":         int(dut.io_read_detected.value),
            "io_write_detected":        int(dut.io_write_detected.value),
            "cfg_read0_detected":       int(dut.cfg_read0_detected.value),
            "cfg_write0_detected":      int(dut.cfg_write0_detected.value),
            "cfg_read1_detected":       int(dut.cfg_read1_detected.value),
            "cfg_write1_detected":      int(dut.cfg_write1_detected.value),
            "completion_detected":      int(dut.completion_detected.value),
            "completion_data_detected": int(dut.completion_data_detected.value),
        }
        for sig_name, val in signals.items():
            if val != 0:
                dut._log.error(f"ERROR: {sig_name} mismatch! Got={val}, Exp=0")
                errors += 1

    async def drive_and_check_packet(
        start_char,
        end_char,
        packet_type,
        exp_count,
        exp_mem_read,
        exp_mem_write,
        exp_io_read,
        exp_io_write,
        exp_cfg_read0,
        exp_cfg_write0,
        exp_cfg_read1,
        exp_cfg_write1,
        exp_completion,
        exp_completion_data
    ):
        """
        Sends a packet, waits for pkt_count to hit exp_count (with timeout),
        then checks detection signals.
        """
        old_count = int(dut.pkt_count.value)

        # Drive the packet
        await drive_packet(start_char, end_char, packet_type)

        # Wait up to 50 cycles for the count to increment
        timeout_cycles = 50
        while int(dut.pkt_count.value) != exp_count and timeout_cycles > 0:
            await RisingEdge(dut.clk)
            timeout_cycles -= 1

        got_count = int(dut.pkt_count.value)
        if got_count != exp_count:
            dut._log.error(f"TIMEOUT or mismatch: pkt_count never reached {exp_count}, still at {got_count}")
            nonlocal errors
            errors += 1
            return

        # Check detection signals on the same cycle
        check_signals = {
            "mem_read_detected":        (int(dut.mem_read_detected.value),        exp_mem_read),
            "mem_write_detected":       (int(dut.mem_write_detected.value),       exp_mem_write),
            "io_read_detected":         (int(dut.io_read_detected.value),         exp_io_read),
            "io_write_detected":        (int(dut.io_write_detected.value),        exp_io_write),
            "cfg_read0_detected":       (int(dut.cfg_read0_detected.value),       exp_cfg_read0),
            "cfg_write0_detected":      (int(dut.cfg_write0_detected.value),      exp_cfg_write0),
            "cfg_read1_detected":       (int(dut.cfg_read1_detected.value),       exp_cfg_read1),
            "cfg_write1_detected":      (int(dut.cfg_write1_detected.value),      exp_cfg_write1),
            "completion_detected":      (int(dut.completion_detected.value),      exp_completion),
            "completion_data_detected": (int(dut.completion_data_detected.value), exp_completion_data),
        }
        for sig_name, (got, exp) in check_signals.items():
            if got != exp:
                dut._log.error(f"ERROR: {sig_name} mismatch! Got={got}, Exp={exp}")
                errors += 1

    # ---------------------------
    # 3) Test Execution
    # ---------------------------

    # Wait until reset is deasserted
    while dut.reset.value == 0:
        await RisingEdge(dut.clk)

    # 1) Valid MRd -> pkt_count=1
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x00, 1,
        exp_mem_read=1, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 2) Valid MWr -> pkt_count=2
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x01, 2,
        exp_mem_read=0, exp_mem_write=1, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 3) Invalid packet (wrong end) -> pkt_count=2
    await drive_packet(START_CHAR, 0xCA, 0x02)
    await check_no_increment(2)

    # 4) Two back-to-back valid packets -> pkt_count=4
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x00, 3,
        exp_mem_read=1, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x01, 4,
        exp_mem_read=0, exp_mem_write=1, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 5) Unknown command (0xFF) -> pkt_count=5
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0xFF, 5,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 6) Invalid end symbol -> pkt_count=5
    await drive_packet(START_CHAR, 0xAA, 0x02)
    await check_no_increment(5)

    # 7) Invalid start character -> pkt_count=5
    await drive_packet(0xAB, END_CHAR, 0x00)
    await check_no_increment(5)

    # 8) Multiple invalid packets -> pkt_count=5
    await drive_packet(START_CHAR, 0xCA, 0x01)
    await check_no_increment(5)
    await drive_packet(START_CHAR, 0xCC, 0x00)
    await check_no_increment(5)

    # 9) i/o read -> pkt_count=6
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x02, 6,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=1, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 10) i/o write -> pkt_count=7
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x42, 7,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=1,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 11) cfg_read0 -> pkt_count=8
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x04, 8,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=1, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 12) cfg_write0 -> pkt_count=9
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x44, 9,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=1, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 13) cfg_read1 -> pkt_count=10
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x05, 10,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=1, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=0
    )

    # 14) cfg_write1 -> pkt_count=11
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x45, 11,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=1,
        exp_completion=0, exp_completion_data=0
    )

    # 15) completion_detected -> pkt_count=12
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x0A, 12,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=1, exp_completion_data=0
    )

    # 16) completion_data_detected -> pkt_count=13
    await drive_and_check_packet(
        START_CHAR, END_CHAR, 0x4A, 13,
        exp_mem_read=0, exp_mem_write=0, exp_io_read=0, exp_io_write=0,
        exp_cfg_read0=0, exp_cfg_write0=0, exp_cfg_read1=0, exp_cfg_write1=0,
        exp_completion=0, exp_completion_data=1
    )

    # Final result
    if errors == 0:
        dut._log.info("TEST PASSED")
    else:
        dut._log.error(f"TEST FAILED with {errors} errors")
