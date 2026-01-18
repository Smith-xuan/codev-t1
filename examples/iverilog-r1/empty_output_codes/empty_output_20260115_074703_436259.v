// Verilog code that resulted in empty output
// Saved at: 2026-01-15T07:47:03.436285
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

module test;
  wire bufif0_out, bufif1_out;
  reg in, ctl;
  
  bufif0 bufif0_g (bufif0_out, in, ctl);
  bufif1 bufif1_g (bufif1_out, in, ctl);
  
  initial begin
    $display("Testing bufif0 and bufif1:");
    $display("in ctl | bufif0_out bufif1_out");
    in = 0; ctl = 0; #10 $display("%b   %b   |   %b        %b      ", in, ctl, bufif0_out, bufif1_out);
    in = 0; ctl = 1; #10 $display("%b   %b   |   %b        %b      ", in, ctl, bufif0_out, bufif1_out);
    in = 1; ctl = 0; #10 $display("%b   %b   |   %b        %b      ", in, ctl, bufif0_out, bufif1_out);
    in = 1; ctl = 1; #10 $display("%b   %b   |   %b        %b      ", in, ctl, bufif0_out, bufif1_out);
  end
endmodule

module testbench;
  initial begin
    #100 $finish;
  end
endmodule
