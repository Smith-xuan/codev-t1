// Verilog code that resulted in empty output
// Saved at: 2026-01-14T17:30:32.754936
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

module pwm (
    input reset,
    input clk,
    input [2:0] mode,
    output out
);

    reg [19:0] counter;
    wire [19:0] threshold;

    // Counter logic
    always @(posedge clk) begin
        if (reset) begin
            counter <= 20'd0;
        end else begin
            if (counter == 20'd999_999) begin
                counter <= 20'd0;
            end else begin
                counter <= counter + 20'd1;
            end
        end
    end

    // Threshold lookup based on mode
    assign threshold =
        (mode == 3'd0) ? 20'd0 :
        (mode == 3'd1) ? 20'd50_000 :
        (mode == 3'd2) ? 20'd250_000 :
        (mode == 3'd3) ? 20'd500_000 :
        (mode == 3'd4) ? 20'd750_000 :
        (mode == 3'd5) ? 20'd1_000_000 :
        /* default */ 20'd0;

    // Output logic (combinational)
    assign out = (counter < threshold);

endmodule

module testbench;
    reg reset;
    reg clk;
    reg [2:0] mode;
    wire out;

    pwm dut (
        .reset(reset),
        .clk(clk),
        .mode(mode),
        .out(out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Initialize
        reset = 1;
        mode = 3'd0;
        #20;
        reset = 0;

        // Test mode 0 (0% duty cycle)
        mode = 3'd0;
        #10000000; // Wait for many cycles
        // Observe that out is always 0

        // Test mode 5 (100% duty cycle)
        mode = 3'd5;
        #10000000; // Wait
        // Observe that out is always 1 (should be)

        // Test mode 1 (5% duty cycle)
        mode = 3'd1;
        #10000000; // Wait
        // Check that out high for first 50,000 cycles of each period

        // Test mode 2 (25% duty cycle)
        mode = 3'd2;
        #10000000;

        // Test mode 3 (50% duty cycle)
        mode = 3'd3;
        #10000000;

        // Test mode 4 (75% duty cycle)
        mode = 3'd4;
        #10000000;

        $finish;
    end

endmodule
