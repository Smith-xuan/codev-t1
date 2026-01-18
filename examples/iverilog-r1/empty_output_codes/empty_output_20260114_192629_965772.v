// Verilog code that resulted in empty output
// Saved at: 2026-01-14T19:26:29.965819
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

module Semaforo(clk, rst, r, a, v);
  input clk, rst;
  output r, a, v;
  
  reg [5:0] count; // enough for 0-62 (63 values)
  
  assign r = (count < 40);
  assign v = (count >= 40 && count < 60);
  assign a = (count >= 60);
  
  always @(posedge clk) begin
    if (rst) begin
      count <= 0;
    end else begin
      if (count == 62)
        count <= 0;
      else
        count <= count + 1;
    end
  end
endmodule

module testbench;
  reg clk;
  reg rst;
  wire r, a, v;
  
  Semaforo dut (.clk(clk), .rst(rst), .r(r), .a(a), .v(v));
  
  initial begin
    clk = 0;
    rst = 1;
    
    // Apply reset
    @(posedge clk);
    rst <= 0;
    
    // Monitor outputs for a few cycles
    $display("Time\tCount\tR\tA\tV");
    $monitor("%0d\t%0d\t%0d\t%0d\t%0d", $time, dut.count, r, a, v);
    
    // Run for enough cycles to see full cycle (at least 2 full cycles)
    // Each full cycle is 63 cycles.
    repeat (200) @(posedge clk);
    
    $finish;
  end
endmodule
