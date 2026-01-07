// Verilog code that resulted in empty output
// Saved at: 2026-01-06T04:41:49.454953
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

module counter (
    input clk,
    input rst,
    output reg [7:0] value
);

    // Internal 25-bit counter
    reg [24:0] ctr_q;

    // Counter logic
    always @(posedge clk) begin
        if (rst) begin
            ctr_q <= 25'b0;
        end else begin
            ctr_q <= ctr_q + 1'b1;
        end
    end

    // Extract top 8 bits of counter
    wire [7:0] ctr_top_bits = ctr_q[23:16];

    // Output logic: invert when MSB is high
    always @* begin
        if (ctr_q[24]) begin
            value = ~ctr_top_bits;
        end else begin
            value = ctr_top_bits;
        end
    end

endmodule

module testbench;
    reg clk;
    reg rst;
    wire [7:0] value;

    // Instantiate DUT
    counter dut (
        .clk(clk),
        .rst(rst),
        .value(value)
    );

    // Clock generation (finite cycles)
    initial begin
        clk = 0;
        repeat (200) #5 clk = ~clk; // 200 edges (100 cycles)
    end

    // Stimulus and checking
    integer cycle;
    reg [24:0] expected_ctr;
    reg [7:0] expected_top_bits;
    reg expected_value;

    initial begin
        // Initialize signals
        rst = 1'b1;
        // Wait for a clock edge
        @(posedge clk);
        #1;

        // Check reset state
        expected_ctr = 25'b0;
        expected_top_bits = expected_ctr[23:16];
        expected_value = expected_top_bits; // MSB is low
        if (value !== expected_value) begin
            $display("ERROR: Reset failed. Expected value=%b, got %b", expected_value, value);
            $finish(1);
        end

        // Release reset
        rst = 1'b0;

        // Test each clock cycle after reset
        for (cycle = 1; cycle <= 100; cycle = cycle + 1) begin
            expected_ctr = cycle; // after each rising edge, counter should be cycle
            // Update top bits based on expected_ctr
            expected_top_bits = expected_ctr[23:16];
            if (expected_ctr[24]) begin
                expected_value = ~expected_top_bits;
            end else begin
                expected_value = expected_top_bits;
            end

            // Wait for next rising edge (counter updates)
            @(posedge clk);
            #1; // wait for combinational output

            // Check output
            if (value !== expected_value) begin
                $display("ERROR at cycle %0d: expected value=%b, got %b", cycle, expected_value, value);
                $display("  expected_ctr = %d (%b)", expected_ctr, expected_ctr);
                $finish(1);
            end
        end

        $display("All tests passed!");
        $finish(0);
    end

endmodule
