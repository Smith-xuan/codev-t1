// Verilog code that resulted in empty output
// Saved at: 2026-01-15T03:59:25.067316
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

module debounce(
    output pb_debounced,
    input pb,
    input clk
);

reg [3:0] shift_reg = 4'b0000;  // 4-bit shift register initialized to all zeros

always @(posedge clk) begin
    // Shift left: oldest bit shifts out, new pb sample shifts in at LSB
    shift_reg <= {shift_reg[2:0], pb};
end

// Debounced output: 0 only when all four sampled values are 0
// Otherwise (any 1 present), output is 1
assign pb_debounced = |shift_reg;

endmodule

module testbench;
    reg clk;
    reg pb;
    wire pb_debounced;
    
    debounce dut (.pb_debounced(pb_debounced), .pb(pb), .clk(clk));
    
    // Generate 100Hz clock (period 10ms)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 5ms half period => 100Hz
    end
    
    initial begin
        // Initialize inputs
        pb = 1'b1; // not pressed initially
        
        // Let's wait a few cycles to see behavior
        #1000; // wait 1ms (100 cycles)
        
        // Test scenario:
        // 1. pb stays 0 for exactly three cycles
        pb = 1'b0;
        #150; // wait for three clock edges (30ms?) Actually 150us? Wait, clock period 10ms, half period 5ms.
        // Let's count: We need to simulate three clock cycles: each cycle 10ms, but we use # delays in testbench.
        // Let's do simpler: wait for 30 clock cycles (300ms) but we can simulate quickly.
        // Instead, we'll manually control timing with explicit clock edges.
        // Let's redesign test to focus on specific transitions.
        $stop;
    end
endmodule
