// Verilog code that resulted in empty output
// Saved at: 2026-01-05T22:34:22.529026
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

`timescale 1ns / 1ps

module seven_segment_display (
    input clk,
    input reset,  // active-low
    output reg [7:0] HEX0
);

    // Counter for 1 second delay (50 MHz clock)
    reg [31:0] counter;
    reg tick;  // tick when counter reaches max

    // Hex digit register (0-15)
    reg [3:0] hex_digit;

    // Parameters for clock frequency
    localparam COUNTER_MAX = 50_000_000 - 1;  // 1 second delay
    localparam COUNTER_SIM = 5 - 1;  // For simulation faster

    // Choose simulation parameter
    // In real hardware, use COUNTER_MAX; for simulation, use COUNTER_SIM.
    // We'll use a macro like `ifdef SIM but for simplicity just select.
    // Define SIMULATION for simulation testbench.
    // We'll use 50_000_000 for now but in testbench we can override via parameter.

    // Scaled down for simulation (comment out for real)
    // localparam COUNTER_MAX = COUNTER_SIM;

    // Counter logic
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            counter <= 0;
            tick <= 0;
        end else begin
            if (counter == COUNTER_MAX) begin
                counter <= 0;
                tick <= 1;
            end else begin
                counter <= counter + 1;
                tick <= 0;
            end
        end
    end

    // Hex digit logic
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            hex_digit <= 0;
        end else begin
            if (tick) begin
                hex_digit <= hex_digit + 1;  // wraps automatically from 15 to 0
            end
        end
    end

    // Seven-segment decoder (active-low)
    always @(*) begin
        case (hex_digit)
            4'h0: HEX0 = 8'b11000000;  // 0
            4'h1: HEX0 = 8'b11111001;  // 1
            4'h2: HEX0 = 8'b10100100;  // 2
            4'h3: HEX0 = 8'b10110000;  // 3
            4'h4: HEX0 = 8'b10011001;  // 4
            4'h5: HEX0 = 8'b10010010;  // 5
            4'h6: HEX0 = 8'b10000010;  // 6
            4'h7: HEX0 = 8'b11111000;  // 7
            4'h8: HEX0 = 8'b10000000;  // 8
            4'h9: HEX0 = 8'b10010000;  // 9
            4'hA: HEX0 = 8'b10001000;  // A
            4'hb: HEX0 = 8'b10000011;  // b
            4'hC: HEX0 = 8'b11000110;  // C
            4'hd: HEX0 = 8'b10001101;  // d
            4'hE: HEX0 = 8'b10000110;  // E
            4'hF: HEX0 = 8'b10001110;  // F
            default: HEX0 = 8'b11111111;
        endcase
    end

endmodule

// Testbench
module testbench;
    reg clk;
    reg reset;
    wire [7:0] HEX0;

    // Instantiate DUT with simulation parameter
    // Override COUNTER_MAX to small value for quick simulation
    // We can't directly override parameter from testbench, so we'll instantiate with localparam.
    // Instead, we'll use a macro define SIMULATION, but for simplicity we'll modify the DUT.
    // Let's create a wrapper module that uses a smaller counter.

    // For simulation, we'll use 5 clock cycles per second.
    // We'll define a new module that inherits from original but overrides parameter.
    // But easier: create a separate test module that redefines localparam.
    // We'll just duplicate the module with a different parameter name and adjust.

    // Actually we can use `ifdef SIMULATION. Let's define SIMULATION in testbench.
    // We'll change the code temporarily to support simulation parameter.

    // Let's rewrite the module with a parameter to allow simulation scaling.
    // We'll do that now.

endmodule
