// Verilog code that resulted in empty output
// Saved at: 2026-01-13T22:03:09.688857
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

module debounce (
    input clock,
    input reset,
    input [3:0] button,
    output [3:0] out
);

    // Debounce period in clock cycles (100 MHz)
    localparam DEBOUNCE_CYCLES = 4000;
    // Counter width needed
    localparam COUNTER_WIDTH = $clog2(DEBOUNCE_CYCLES + 1); // +1 to include DEBOUNCE_CYCLES
    localparam COUNTER_MAX = DEBOUNCE_CYCLES;

    // Two-stage synchronizer
    reg [3:0] sync0; // first stage
    reg [3:0] sync1; // second stage (synchronized input)

    always @(posedge clock) begin
        if (reset) begin
            sync0 <= 4'b0;
            sync1 <= 4'b0;
        end else begin
            sync0 <= button;
            sync1 <= sync0;
        end
    end

    // Debounce counters and output register
    reg [COUNTER_WIDTH-1:0] counter [3:0];
    reg [3:0] out_reg;

    assign out = out_reg;

    integer i;
    always @(posedge clock) begin
        if (reset) begin
            for (i = 0; i < 4; i = i + 1) begin
                counter[i] <= 0;
                out_reg[i] <= 1'b0;
            end
        end else begin
            for (i = 0; i < 4; i = i + 1) begin
                if (sync1[i] != out_reg[i]) begin // input differs from current output
                    if (counter[i] == COUNTER_MAX) begin
                        // Debounce period completed
                        out_reg[i] <= sync1[i];
                        counter[i] <= 0;
                    end else begin
                        counter[i] <= counter[i] + 1;
                    end
                end else begin
                    // Input matches current output, reset counter
                    counter[i] <= 0;
                end
            end
        end
    end

endmodule

module testbench;
    reg clock;
    reg reset;
    reg [3:0] button;
    wire [3:0] out;

    // Override debounce cycles for simulation (smaller)
    // We'll create a module with parameter
    // But we can just instantiate with localparam change? Instead, let's create a separate test module.
    // However, we can keep the original module with DEBOUNCE_CYCLES = 4000, but we can't simulate that easily.
    // Let's create a wrapper that uses a parameter.
    // We'll just instantiate the original module and adjust testbench to wait appropriate time.
    // Since we can't change the constant, we'll just wait 4000*10ns = 40us.
    // But that's long simulation. Let's change the design to have a parameter.
    
    // Actually we can't modify the original module as per user request? The user wants the final module.
    // We can still test with reduced debounce cycles by redefining the constant in testbench via hierarchical reference? Not possible in Verilog.
    // Let's create a version with parameter for testing.
    // Since we are allowed to write code, we'll modify the design to have a parameter DEBOUNCE_CYCLES = 4000.
    
    // Let's create a new module 'debounce_param' with parameter.
    // But we need to deliver the final module named 'debounce' with 4000 cycles.
    // For testing, we can temporarily override the constant using `defparam`.
    
    // Let's do: instantiate debounce and use defparam to change DEBOUNCE_CYCLES to 5.
    // However, DEBOUNCE_CYCLES is a localparam, not a parameter. So defparam won't work.
    
    // We need to modify the module to have a parameter.
    // I'll do that for testing purposes, then later revert to localparam for final answer.
    // Let's create a module with parameter DEBOUNCE_CYCLES = 4000, default.
    // Then in testbench, instantiate with #5.
    
    // Let's define a new module debounce_param.
    
endmodule
