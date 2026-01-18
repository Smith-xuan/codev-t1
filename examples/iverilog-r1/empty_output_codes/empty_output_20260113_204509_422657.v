// Verilog code that resulted in empty output
// Saved at: 2026-01-13T20:45:09.422686
// 
// Metadata:
//   status: success
//   api_status: Success
//   compile_status: Finished
//   run_status: Finished
//   compile_stderr: N/A
//   stdout: N/A
//   stderr: N/A
//   exit_code: 0
//
// Full metadata (JSON):
{
  "case_index": 0,
  "input": "",
  "expected_output": null,
  "api_request_error": null,
  "api_response": {
    "status": "Success",
    "message": "",
    "compile_result": {
      "status": "Finished",
      "return_code": 0,
      "stdout": "",
      "stderr": "",
      "execution_time": 0.0
    },
    "run_result": {
      "status": "Finished",
      "return_code": 0,
      "stdout": "",
      "stderr": "",
      "execution_time": 0.0
    },
    "files": {}
  },
  "status": "success",
  "stdout": "",
  "stderr": "",
  "exit_code": 0,
  "duration": 0.0,
  "compile_duration": 0.0,
  "compile_stderr": "",
  "api_status": "Success",
  "compile_status": "Finished",
  "run_status": "Finished"
}

// ============================================================================
// Verilog Code:
// ============================================================================

// stopwatch module with 4-digit BCD counter
module stopwatch #(
    parameter CLK_FREQ = 50_000_000   // default 50 MHz
) (
    input clk,
    input enable,
    input up,
    input reset,
    output [15:0] digits
);

    // Compute number of clock cycles per 100ms (tick period)
    localparam TICK_CYCLES = CLK_FREQ / 10;  // cycles per 0.1 second

    // 24-bit timer for generating periodic tick
    reg [23:0] timer;

    // Tick generation: pulse low when timer reaches TICK_CYCLES-1 and enable is high
    wire tick;
    assign tick = (timer == TICK_CYCLES - 1) && enable;

    // Binary counter for ticks (0 to 9999)
    reg [13:0] tick_count;  // up to 9999 (13 bits needed: 2^13=8192, but we need up to 9999 so 14 bits)

    // BCD conversion function
    function [15:0] binary_to_bcd(input [13:0] bin);
        reg [15:0] bcd;
        integer i;
        begin
            bcd = 16'd0;
            // Left shift binary bit into BCD digits
            // Process from MSB to LSB of binary
            for (i = 13; i >= 0; i = i - 1) begin
                // Adjust each BCD digit before shift
                if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
                if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
                if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
                if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;
                // Shift left by 1, shifting in binary bit i
                bcd = {bcd[14:0], bin[i]};
            end
            binary_to_bcd = bcd;
        end
    endfunction

    // Tick counter update
    always @(posedge clk) begin
        if (reset) begin
            timer <= 0;
            tick_count <= 0;
        end else begin
            // Timer logic
            if (enable) begin
                if (timer == TICK_CYCLES - 1)
                    timer <= 0;
                else
                    timer <= timer + 1;
            end

            // Tick counter update on tick
            if (tick) begin
                // Wrap-around increment/decrement
                if (up) begin
                    if (tick_count == 14'd9999)
                        tick_count <= 0;
                    else
                        tick_count <= tick_count + 1;
                end else begin
                    if (tick_count == 0)
                        tick_count <= 14'd9999;
                    else
                        tick_count <= tick_count - 1;
                end
            end
        end
    end

    // Output assignment
    assign digits = binary_to_bcd(tick_count);

endmodule

// Testbench
module testbench;

    // Instantiate DUT with a low clock frequency for simulation
    // Let's set CLK_FREQ = 100 Hz, so TICK_CYCLES = 10 cycles
    // Actually we need larger tick period for simulation.
    // Let's set CLK_FREQ = 10 (10 Hz) then TICK_CYCLES = 1 cycle? Wait: 100ms = 0.1 s.
    // At 10 Hz, period = 0.1 s, which equals 100 ms. So TICK_CYCLES = 1.
    // That would mean tick every clock cycle. That's fine for simulation.
    // Let's set CLK_FREQ = 10, meaning 10 Hz clock.
    // Then timer counts to 0 (since TICK_CYCLES-1 = 0) and tick asserted every cycle when enable high.

    reg clk;
    reg enable;
    reg up;
    reg reset;
    wire [15:0] digits;

    stopwatch #(.CLK_FREQ(10)) dut (
        .clk(clk),
        .enable(enable),
        .up(up),
        .reset(reset),
        .digits(digits)
    );

    // Clock generation: period = 100 ms? No, clock period corresponds to CLK_FREQ parameter.
    // Since CLK_FREQ = 10 Hz, period = 1/10 = 0.1 seconds = 100 ms.
    // That means one clock cycle is 100 ms. So tick every cycle.
    // We'll set clock period to 100 ms for simplicity in simulation.
    // However, simulation time will be long if we simulate many cycles.
    // Let's set CLK_FREQ = 1000 Hz, then tick every 100 ms = 10 cycles.
    // Let's do CLK_FREQ = 1000 Hz, so period = 1 ms, tick every 10 cycles.

    // Let's change parameter to 1000 Hz.
    // Actually we can keep parameter but set to 1000 Hz. Let's compute: TICK_CYCLES = 1000 / 10 = 100 cycles.
    // That's fine.
    // We'll generate clock with period 1 ms (1 MHz). Simulate for several ticks.

    // Let's set CLK_FREQ = 1_000_000 (1 MHz). Then tick every 0.1 s = 100,000 cycles.
    // Too many for simulation. So we need to scale down.
    // We'll use a parameter that is convenient for simulation.
    // Let's set CLK_FREQ = 100 (100 Hz) => TICK_CYCLES = 10 cycles.
    // Clock period = 10 ms. Tick period = 100 ms = 10 cycles.
    // That's fine for simulation.
    // Let's set CLK_FREQ = 100.

    // So TICK_CYCLES = 100 / 10 = 10 cycles.

    // Let's adjust the code.

endmodule
