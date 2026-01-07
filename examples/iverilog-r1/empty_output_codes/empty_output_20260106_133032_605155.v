// Verilog code that resulted in empty output
// Saved at: 2026-01-06T13:30:32.605183
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

module test_case;
    reg [3:0] r;
    reg [2:0] y1;
    
    always @(*) begin
        case (r)
            4'b0000: y1 = 0;
            4'b0001: y1 = 1;
            default: y1 = 2;
        endcase
    end
    
    initial begin
        r = 0;
        #10;
        $display("r=%b, y1=%b", r, y1);
        r = 1;
        #10;
        $display("r=%b, y1=%b", r, y1);
        r = 2;
        #10;
        $display("r=%b, y1=%b", r, y1);
        $finish;
    end
endmodule

module testbench;
    // nothing needed
endmodule
