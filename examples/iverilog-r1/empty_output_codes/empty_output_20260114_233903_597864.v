// Verilog code that resulted in empty output
// Saved at: 2026-01-14T23:39:03.597921
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

module SR_to_JK (clk, rst, j, k, q, qbar);
  input clk, rst, j, k;
  output reg q;
  output qbar;
  
  assign qbar = ~q;
  
  always @(posedge clk) begin
    if (rst) begin
      q <= 1'b0;
    end else begin
      case ({j,k})
        2'b00: q <= q;      // hold
        2'b01: q <= 1'b0;   // reset
        2'b10: q <= 1'b1;   // set
        2'b11: q <= ~q;     // toggle
      endcase
    end
  end
endmodule

module testbench;
  reg clk, rst, j, k;
  wire q, qbar;
  
  SR_to_JK dut (.clk(clk), .rst(rst), .j(j), .k(k), .q(q), .qbar(qbar));
  
  initial begin
    clk = 0;
    rst = 0;
    j = 0;
    k = 0;
    
    // Test reset
    rst = 1;
    @(posedge clk);
    rst = 0;
    if (q !== 1'b0) begin
      $display("ERROR: Reset failed, q = %b", q);
      $finish;
    end
    
    // Test hold
    @(posedge clk);
    j = 0; k = 0;
    @(posedge clk);
    if (q !== 1'b0) begin
      $display("ERROR: Hold after reset failed, q = %b", q);
      $finish;
    end
    
    // Test set
    j = 1; k = 0;
    @(posedge clk);
    if (q !== 1'b1) begin
      $display("ERROR: Set failed, q = %b", q);
      $finish;
    end
    
    // Test reset
    j = 0; k = 1;
    @(posedge clk);
    if (q !== 1'b0) begin
      $display("ERROR: Reset failed after set, q = %b", q);
      $finish;
    end
    
    // Test toggle from 0
    j = 1; k = 1;
    @(posedge clk);
    if (q !== 1'b1) begin
      $display("ERROR: Toggle from 0 failed, q = %b", q);
      $finish;
    end
    
    // Test toggle from 1
    @(posedge clk);
    if (q !== 1'b0) begin
      $display("ERROR: Toggle from 1 failed, q = %b", q);
      $finish;
    end
    
    $display("All tests passed!");
    $finish;
  end
endmodule
