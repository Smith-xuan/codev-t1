// Verilog code that resulted in empty output
// Saved at: 2026-01-07T04:39:16.124761
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

module RSff (
    input r,
    input s,
    input clk,
    output reg q,
    output qb
);
    assign qb = ~q;
    
    always @(negedge clk) begin
        if (r) q <= 1'b0;
        else if (s) q <= 1'b1;
        // else hold implicit
    end
endmodule

module testbench;
    reg r, s, clk;
    wire q, qb;
    
    RSff dut ( .r(r), .s(s), .clk(clk), .q(q), .qb(qb) );
    
    // Clock generation
    initial begin
        clk = 1'b1;
        repeat (20) begin
            #5 clk = ~clk;
        end
    end
    
    initial begin
        // Initialize
        r = 0; s = 0;
        // Wait for first falling edge, then wait a small delay for non-blocking update
        @(negedge clk);
        #1;
        // Now q should be 'x' (unknown) because no assignment yet
        
        // Apply reset
        r = 1; s = 0;
        @(negedge clk);
        #1;
        if (q !== 1'b0) begin
            $display("FAIL: Reset gave q=%b (expected 0)", q);
            $finish;
        end
        
        // Apply set
        r = 0; s = 1;
        @(negedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Set gave q=%b (expected 1)", q);
            $finish;
        end
        
        // Hold (both low)
        r = 0; s = 0;
        @(negedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Hold gave q=%b (expected 1)", q);
            $finish;
        end
        
        @(negedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Hold 2 gave q=%b (expected 1)", q);
            $finish;
        end
        
        // Set again
        r = 0; s = 1;
        @(negedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Set again gave q=%b (expected 1)", q);
            $finish;
        end
        
        // Reset
        r = 1; s = 0;
        @(negedge clk);
        #1;
        if (q !== 1'b0) begin
            $display("FAIL: Reset after set gave q=%b (expected 0)", q);
            $finish;
        end
        
        // Both high (invalid) should reset (priority to r)
        r = 1; s = 1;
        @(negedge clk);
        #1;
        if (q !== 1'b0) begin
            $display("FAIL: Both high gave q=%b (expected 0)", q);
            $finish;
        end
        
        // Release both, hold
        r = 0; s = 0;
        @(negedge clk);
        #1;
        if (q !== 1'b0) begin
            $display("FAIL: Hold after both high gave q=%b (expected 0)", q);
            $finish;
        end
        
        // Test toggling after reset
        r = 0; s = 1;
        @(negedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Set after both high gave q=%b (expected 1)", q);
            $finish;
        end
        
        // Then both low, hold
        r = 0; s = 0;
        @(negedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Hold after set gave q=%b (expected 1)", q);
            $finish;
        end
        
        // Additional test: change inputs between falling edges
        // Set at next falling edge
        r = 0; s = 1;
        @(negedge clk);
        #1;
        if (q !== 1'b1) begin
            $display("FAIL: Set after previous hold gave q=%b (expected 1)", q);
            $finish;
        end
        
        // Now both high before next falling edge (should not affect until falling edge)
        r = 1; s = 1;
        #1; // wait a short time
        if (q !== 1'b1) begin
            $display("FAIL: Output changed before clock edge: q=%b", q);
            $finish;
        end
        @(negedge clk);
        #1;
        // Should reset now
        if (q !== 1'b0) begin
            $display("FAIL: Reset after glitch failed: q=%b", q);
            $finish;
        end
        
        $display("All tests passed!");
        $finish;
    end
endmodule
