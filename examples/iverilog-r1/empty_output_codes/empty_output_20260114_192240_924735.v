// Verilog code that resulted in empty output
// Saved at: 2026-01-14T19:22:40.924772
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

module test_sub2;
    reg [3:0] a;
    wire [5:0] res1, res2;
    
    assign res1 = a - 4'd1;
    assign res2 = (a - 4'd1) & 4'hF;
    
    initial begin
        a = 4'b0000;
        #10;
        $display("a=%b res1=%b res2=%b", a, res1, res2);
        
        a = 4'b0001;
        #10;
        $display("a=%b res1=%b res2=%b", a, res1, res2);
        
        a = 4'b1111;
        #10;
        $display("a=%b res1=%b res2=%b", a, res1, res2);
        
        end
endmodule

module testbench;
    /* empty */
endmodule
