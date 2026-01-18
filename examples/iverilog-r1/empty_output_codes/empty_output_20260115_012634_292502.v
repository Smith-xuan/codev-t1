// Verilog code that resulted in empty output
// Saved at: 2026-01-15T01:26:34.292527
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

module SR_FF (
  input clk,
  input s,
  input r,
  input reset,
  input en,
  output reg q
);

always @(posedge clk or posedge reset) begin
  if (reset) begin
    q <= 1'b0;
  end else if (en) begin
    case ({r, s})
      2'b00: ; // hold
      2'b01: ; // hold
      2'b10: q <= 1'b0; // reset when r=1
      2'b11: q <= 1'bx; // unknown
      default: ; // should not happen
    endcase
  end
end

endmodule

module testbench;
  reg clk, s, r, reset, en;
  wire q;
  
  SR_FF dut (clk, s, r, reset, en, q);
  
  initial begin
    clk = 0;
    s = 0;
    r = 0;
    reset = 0;
    en = 0;
    
    // Test async reset
    #10 reset = 1;
    #10 reset = 0;
    
    // Test hold when enable low
    #10 en = 0;
    #10 s = 1; r = 0;
    #10 clk = 1; #10 clk = 0;
    
    // Test s=0,r=1 reset
    #10 en = 1;
    #10 s = 0; r = 1;
    #10 clk = 1; #10 clk = 0;
    
    // Test both=1 unknown
    #10 s = 1; r = 1;
    #10 clk = 1; #10 clk = 0;
    
    // Test hold s=1,r=0
    #10 s = 1; r = 0;
    #10 clk = 1; #10 clk = 0;
    
    // Test reset overrides clock
    #10 reset = 1;
    #10 en = 1;
    #10 s = 1; r = 0;
    #10 clk = 1; #10 clk = 0;
    #10 reset = 0;
    
    #10 $finish;
  end
  
endmodule
