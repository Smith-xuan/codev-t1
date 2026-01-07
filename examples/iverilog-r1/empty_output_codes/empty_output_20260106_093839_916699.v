// Verilog code that resulted in empty output
// Saved at: 2026-01-06T09:38:39.916728
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
    reg [7:0] a;
    reg [1:0] sh;
    reg [7:0] b;
    reg signed [7:0] c;
    reg [7:0] d;
    
    initial begin
        a = 8'b11110101; // -11 as unsigned 250
        sh = 2'b01;
        b = a >>> sh; // logical shift? arithmetic?
        c = a; // a is unsigned, but assign to signed
        d = $signed(a) >>> sh; // signed shift
        
        $display("Unsigned a = %b (unsigned %0d)", a, a);
        $display("Signed a = %b (%0d signed)", $signed(a), $signed(a));
        $display("a >>> sh (unsigned) = %b (unsigned %0d)", b, b);
        $display("$signed(a) >>> sh = %b (%0d signed)", d, $signed(d));
        
        // more test
        a = 8'b10000000; // -128
        sh = 2'b01;
        b = a >>> sh;
        d = $signed(a) >>> sh;
        $display("\na = %b (unsigned %0d)", a, a);
        $display("Signed a = %b (%0d signed)", $signed(a), $signed(a));
        $display("a >>> sh = %b (unsigned %0d)", b, b);
        $display("$signed(a) >>> sh = %b (%0d signed)", d, $signed(d));
        
        // test with positive
        a = 8'b01110101; // 117 unsigned,  -103 signed?
        sh = 2'b10;
        b = a >>> sh;
        d = $signed(a) >>> sh;
        $display("\na = %b (unsigned %0d)", a, a);
        $display("Signed a = %b (%0d signed)", $signed(a), $signed(a));
        $display("a >>> sh = %b (unsigned %0d)", b, b);
        $display("$signed(a) >>> sh = %b (%0d signed)", d, $signed(d));
        
        $finish;
    end
endmodule

module testbench;
    // dummy
endmodule
