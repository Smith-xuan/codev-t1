// Verilog code that resulted in empty output
// Saved at: 2026-01-07T06:13:33.732652
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

module test_concat;
    reg [32:0] vec;
    initial begin
        vec = {8'd127, 23'h600000};
        $display("vec = %h", vec);
        $display("vec[32:25] = %h", vec[32:25]);
        $display("vec[24:0] = %h", vec[24:0]);
        $display("vec binary: %b", vec);
        $finish;
    end
endmodule

module testbench;
    // ensure top module is testbench
endmodule
