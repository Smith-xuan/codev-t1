// Verilog code that resulted in empty output
// Saved at: 2026-01-06T03:35:19.873099
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

module shift_test;
    reg [31:0] a;
    wire [31:0] b;
    assign b = a << 2;
    initial begin
        a = 32'hFFFF_FFFC;
        #1;
        $display("a=0x%08x, b=0x%08x", a, b);
        // compute expected
        $display("expected: 0x%08x", (a * 4) & 32'hFFFFFFFF);
        $finish;
    end
endmodule

module testbench;
    // dummy to satisfy tool
endmodule
