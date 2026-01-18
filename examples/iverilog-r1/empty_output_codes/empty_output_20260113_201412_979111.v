// Verilog code that resulted in empty output
// Saved at: 2026-01-13T20:14:12.979144
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

module fibo(
  input clock,
  input reset,
  output [31:0] value
);

reg [31:0] reg0, reg1;

assign value = reg0;

always @(posedge clock) begin
  if (reset) begin
    reg0 <= 32'd0;
    reg1 <= 32'd1;
  end else begin
    reg0 <= reg1;
    reg1 <= reg0 + reg1;
  end
end

endmodule

module testbench;
  reg clock;
  reg reset;
  wire [31:0] value;
  
  fibo dut (.clock(clock), .reset(reset), .value(value));
  
  initial begin
    clock = 0;
    reset = 0;
    
    // Apply reset for one clock cycle
    @(negedge clock); // wait for negedge to ensure timing
    reset = 1;
    @(posedge clock); // wait for posedge while reset is high
    // At this posedge, registers get reset values
    #1 reset = 0; // deassert after a small delay
    
    // Now generate Fibonacci sequence
    $display("Time\tClock\tReset\tValue\tExpected");
    
    // Expected sequence: 0,1,1,2,3,5,8,13,21,34,55...
    // After reset, output should be 0 (F0)
    // At first clock edge after reset, output becomes 1 (F1)
    // etc.
    
    // We'll sample at each posedge clock after reset deassertion
    // The first posedge after reset deassertion will cause transition to 1.
    // Let's count cycles.
    
    // Start monitoring
    $monitor("%0d\t%b\t%b\t%d", $time, clock, reset, value);
    
    // Generate 10 clock cycles
    repeat (10) @(posedge clock);
    
    $finish;
  end
endmodule
