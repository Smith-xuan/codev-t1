// Verilog code that resulted in empty output
// Saved at: 2026-01-06T07:03:43.118634
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

module register (
    input [15:0] x,
    input clk,
    input enable,
    output reg [15:0] y
);
always @(posedge clk) begin
    if (enable)
        y <= x;
end
endmodule

module testbench;
    reg [15:0] x;
    reg clk, enable;
    wire [15:0] y;
    
    register dut (.x(x), .clk(clk), .enable(enable), .y(y));
    
    initial begin
        clk = 0;
        enable = 0;
        x = 16'h1234;
        #10 clk = 1;
        #10 clk = 0;
        #10 enable = 1;
        x = 16'h5678;
        #10 clk = 1;
        #10 clk = 0;
        #10 enable = 0;
        x = 16'h9abc;
        #10 clk = 1;
        #10 clk = 0;
        #10 $finish;
    end
endmodule
