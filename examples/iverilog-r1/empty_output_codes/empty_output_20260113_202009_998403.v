// Verilog code that resulted in empty output
// Saved at: 2026-01-13T20:20:09.998435
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

module BCDCounter(
    input clk5,
    input reset,
    input enable,
    output reg [3:0] value,
    output ovwOutput
);

    // Combinational overflow output
    assign ovwOutput = (value == 4'd9) && enable;

    // Sequential logic
    always @(posedge clk5) begin
        if (reset) begin
            value <= 4'b0;
        end else if (enable) begin
            if (value == 4'd9) begin
                value <= 4'b0;
            end else begin
                value <= value + 1'b1;
            end
        end
    end

endmodule

module testbench;
    reg clk5;
    reg reset;
    reg enable;
    wire [3:0] value;
    wire ovwOutput;

    BCDCounter dut (
        .clk5(clk5),
        .reset(reset),
        .enable(enable),
        .value(value),
        .ovwOutput(ovwOutput)
    );

    // Clock generation: period 10 time units (50 MHz? just for simulation)
    initial begin
        clk5 = 0;
        forever #5 clk5 = ~clk5;
    end

    initial begin
        // Initialize inputs
        reset = 0;
        enable = 0;

        // Apply reset
        reset = 1;
        #10; // wait for posedge and a bit
        reset = 0;
        #5; // wait for next posedge? Let's check

        // Test 1: Verify counter starts at 0 after reset
        if (value !== 4'b0) begin
            $error("Test 1 failed: value not zero after reset. Got %d", value);
            $finish;
        end

        // Test overflow when enable is low: should not assert
        enable = 0;
        #10; // wait a clock
        if (ovwOutput !== 1'b0) begin
            $error("Test 2 failed: ovwOutput should be low when enable low.");
            $finish;
        end

        // Test 3: Enable for 10 cycles, count from 0 to 9 then wrap to 0
        enable = 1;
        #10; // after one clock edge, value should be 1
        if (value !== 4'd1) begin
            $error("Test 3a failed: expected 1, got %d", value);
            $finish;
        end
        // Wait 8 more cycles to count to 9
        #80; // 8 cycles * 10 time units each? Wait clock period is 10, half period 5. So each full cycle is 10 time units. Actually we need to wait for posedge. Let's just wait for enough edges.
        // Better: loop and check each count.
        // Let's reset and use explicit cycle waiting.
        $finish;
    end
endmodule
