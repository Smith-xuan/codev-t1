// Verilog code that resulted in empty output
// Saved at: 2026-01-13T23:33:35.698517
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

module testbench;
  // Instantiate the test module t
  t dut ();
endmodule

// sub module with parameter A, declares two registers of width A+1
module sub #(parameter A = 1) ();
  reg [A:0] unus1;
  reg [A:0] unus2;
  // lint warning about unused parameter A
  // Note: This warning may be suppressed or duplicated based on tool
endmodule

// test module t instantiating three instances
module t ();
  sub #(.A(1)) sub1 ();
  sub #(.A(2)) sub2 ();
  sub #(.A(3)) sub3 ();
endmodule
