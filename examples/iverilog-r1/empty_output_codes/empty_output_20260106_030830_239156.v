// Verilog code that resulted in empty output
// Saved at: 2026-01-06T03:08:30.239182
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

module test_mag;
    reg signed [15:0] din = -16384;
    wire signed [15:0] mag_signed = (din < 0) ? -din : din;
    wire [15:0] mag_unsigned = (din < 0) ? (~din + 1) : din;
    
    initial begin
        $display("din = %d (hex %h)", din, din);
        $display("mag_signed = %d (hex %h)", mag_signed, mag_signed);
        $display("mag_unsigned = %h", mag_unsigned);
        $finish;
    end
endmodule

module testbench;
    initial begin
        // dummy
    end
endmodule
