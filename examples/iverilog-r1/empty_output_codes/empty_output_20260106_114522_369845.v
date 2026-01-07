// Verilog code that resulted in empty output
// Saved at: 2026-01-06T11:45:22.369872
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

`timescale 1ns/1ps

module self_reset(
    input clk_25,
    output reg reset
);

// Parameters
parameter CLK_FREQ = 25_000_000; // 25 MHz
parameter RESET_WIDTH_US = 10;   // 10 microseconds
// Number of clock cycles = (RESET_WIDTH_US * CLK_FREQ) / 1_000_000
// 10 * 25,000,000 / 1,000,000 = 250 cycles
localparam COUNT_MAX = 249;   // 0 to 249 inclusive -> 250 cycles

// Internal counter
reg [8:0] count;      // enough for 250 (0-249)
reg active;

initial begin
    // Initialize to asserted state for power-on
    active = 1'b1;
    reset = 1'b1;
    count = 9'd0;
end

always @(posedge clk_25) begin
    if (active) begin
        if (count == COUNT_MAX) begin
            // Finished counter, deassert reset
            active <= 1'b0;
            reset <= 1'b0;
        end else begin
            count <= count + 1;
        end
    end
end

endmodule

// Testbench
module testbench;
reg clk_25;
wire reset;

// Instantiate DUT
self_reset dut (.clk_25(clk_25), .reset(reset));

// Clock generation: 25 MHz => period 40 ns
initial begin
    clk_25 = 0;
    // Generate clocks for 1000 ns (enough for reset pulse)
    repeat (63) #20 clk_25 = ~clk_25;
    // Continue for a bit more
    repeat (10) #20 clk_25 = 0;
    #1000 $finish;
end

// Variables
integer reset_high_cycles = 0;
reg prev_reset;

// Monitor reset signal
initial begin
    prev_reset = 0;
    wait (clk_25 === 1'b0); // wait for initial clock low
    // Count high cycles
    forever begin
        @(posedge clk_25);
        if (reset) reset_high_cycles = reset_high_cycles + 1;
        prev_reset = reset;
        // Stop if reset goes low and we have counted enough
        if (reset === 1'b0 && reset_high_cycles >= 245) begin
            $display("Reset high cycles = %0d", reset_high_cycles);
            if (reset_high_cycles == 250) begin
                $display("SUCCESS: Reset pulse width correct.");
            end else begin
                $display("ERROR: Expected 250 cycles, got %0d", reset_high_cycles);
            end
            // Continue a bit more
            repeat (5) @(posedge clk_25);
            $finish;
        end
    end
end

endmodule
