// Verilog code that resulted in empty output
// Saved at: 2026-01-07T03:36:35.210464
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

module test_shift;
    reg [31:0] a = 32'h80000000;
    reg [4:0] shamt = 3;
    wire [31:0] res = $signed(a) >>> shamt;
    initial begin
        $display("a = %h (binary %b)", a, a);
        $display("shamt = %d", shamt);
        $display("result = %h (binary %b)", res, res);
        $finish;
    end
endmodule

module testbench;
    
endmodule
