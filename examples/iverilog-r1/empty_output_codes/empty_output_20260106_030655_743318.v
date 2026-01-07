// Verilog code that resulted in empty output
// Saved at: 2026-01-06T03:06:55.743349
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

module test_product;
    reg [15:0] a = 16'h4000;
    reg [15:0] b = 16'h4000;
    wire [31:0] prod = a * b;
    wire [15:0] bits30_15 = prod[30:15];
    
    initial begin
        $display("a = %h", a);
        $display("b = %h", b);
        $display("a * b = %h", prod);
        $display("prod[30:15] = %h", bits30_15);
        $finish;
    end
endmodule

module testbench;
    initial begin
        // This is just to satisfy simulation
    end
endmodule
