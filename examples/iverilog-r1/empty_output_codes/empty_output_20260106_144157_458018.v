// Verilog code that resulted in empty output
// Saved at: 2026-01-06T14:41:57.458048
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

module test_mult;
  reg [15:0] a;
  reg [3:0] b;
  wire [19:0] prod;
  assign prod = a * b;
  
  initial begin
    a = 16'hABCD;
    b = 4'd7;
    #1;
    $display("a = %h, b = %d", a, b);
    $display("prod = %h decimal %d", prod, prod);
    $display("Expected 0x4ACD7 = %d", 20'h4ACD7);
    $display("Expected 0x4ACB7 = %d", 20'h4ACB7);
    $finish;
  end
endmodule

module testbench;
  // No top-level instantiation needed
endmodule
