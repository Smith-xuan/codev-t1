// Verilog code that resulted in empty output
// Saved at: 2026-01-06T08:52:57.532881
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

module iniciadorHalt (
  input clock,
  output reg saida
);

  reg pulsed = 1'b0;  // initial value 0

  always @(posedge clock) begin
    if (!pulsed) begin
      saida <= 1'b1;
      pulsed <= 1'b1;
    end else begin
      saida <= 1'b0;
    end
  end

endmodule

module testbench;
  reg clock;
  wire saida;
  
  iniciadorHalt dut (clock, saida);
  
  reg [31:0] pulse_seen;
  initial begin
    clock = 0;
    pulse_seen = 0;
    // Wait for first rising edge
    @(posedge clock);
    // Pulse should be high now
    #1; // sample after edge
    if (saida !== 1'b1) begin
      $display("ERROR: Pulse not high after first rising edge");
      $finish;
    end
    pulse_seen = pulse_seen + 1;
    
    // Wait for next rising edge
    @(posedge clock);
    #1;
    if (saida !== 1'b0 || pulse_seen != 1) begin
      $display("ERROR: Pulse still high or extra pulse");
      $finish;
    end
    
    // Wait for several more rising edges
    repeat(5) begin
      @(posedge clock);
      #1;
      if (saida !== 1'b0) begin
        $display("ERROR: Output not low after pulse");
        $finish;
      end
    end
    
    // Test clock starts at 1 scenario (reset not available)
    clock = 1;
    #10; // wait a bit
    clock = 0;
    #10;
    clock = 1; // rising edge now
    @(posedge clock);
    #1;
    if (saida !== 1'b0) begin
      $display("ERROR: Should not pulse on first rising edge if clock started at 1");
      $finish;
    end
    
    $display("All tests passed!");
    $finish;
  end
  
endmodule
