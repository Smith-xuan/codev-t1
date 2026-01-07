// Verilog code that resulted in empty output
// Saved at: 2026-01-07T08:42:42.112666
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

module clock(
    input pushButttonClock,
    input fastClk,
    output slowClk,
    output pressClk
);

    // Parameters
    parameter SLOW_DIVIDER = 60;
    parameter DEBOUNCE_TIME = 12_000; // cycles

    // Slow clock generation
    reg [5:0] slow_counter = 0; // counts 0 to SLOW_DIVIDER-1
    reg slowClk_reg = 0;

    // Debouncing logic
    reg [13:0] debounce_counter = 0;
    reg debounced_button = 0;
    reg prev_button = 0;
    reg pressClk_reg = 0;

    // Edge detection
    wire press_rise;

    assign press_rise = debounced_button && !prev_button;

    always @(posedge fastClk) begin
        prev_button <= debounced_button; // store previous debounced state
    end

    // Slow counter
    always @(posedge fastClk) begin
        if (slow_counter == SLOW_DIVIDER - 1) begin
            slow_counter <= 0;
            slowClk_reg <= ~slowClk_reg;
        end else begin
            slow_counter <= slow_counter + 1;
        end
    end

    // Debouncing logic
    always @(posedge fastClk) begin
        if (pushButttonClock == debounced_button) begin
            // Same as current debounced state, increment counter
            if (debounce_counter < DEBOUNCE_TIME) begin
                debounce_counter <= debounce_counter + 1;
            end
        end else begin
            // Different, reset counter
            debounce_counter <= 0;
        end

        // When counter reaches threshold, update debounced button
        if (debounce_counter == DEBOUNCE_TIME) begin
            debounced_button <= pushButttonClock;
        end
    end

    // Press clock generation
    always @(posedge fastClk) begin
        if (press_rise) begin
            pressClk_reg <= ~pressClk_reg;
        end
    end

    // Assign outputs
    assign slowClk = slowClk_reg;
    assign pressClk = pressClk_reg;

endmodule

// Testbench with reduced parameters for faster simulation
module testbench;
    reg pushButttonClock;
    reg fastClk;
    wire slowClk;
    wire pressClk;

    // Instantiate DUT with reduced times for simulation
    // We'll override parameters by passing them as module parameters
    // But we cannot change parameters after elaboration. Let's create a wrapper.
    // Instead, we can use defparam or instantiate with different parameters.
    // For simplicity, we'll just keep default parameters in DUT and test with original values,
    // but we'll simulate for fewer cycles.
    // We'll use SLOW_DIVIDER = 5 and DEBOUNCE_TIME = 5 for quick test.
    // We'll modify the DUT to accept parameters via module input? Not possible.
    // Better to create a separate test module that instantiates clock with parameters.
    // Let's create a separate test module.
endmodule
