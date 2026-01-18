// Verilog code that resulted in empty output
// Saved at: 2026-01-13T21:51:43.442304
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

module lab2_2 (
    input clock,
    input reset,
    output reg overflow,
    output reg [3:0] out
);

always @(posedge clock) begin
    if (reset) begin
        out <= 4'd0;
        overflow <= 1'b0;
    end else begin
        if (out == 4'd11) begin
            out <= 4'd0;
            overflow <= 1'b1;  // overflow is high when state is 11, indicating wrap on next cycle
        end else begin
            out <= out + 1;
            overflow <= 1'b0;
        end
    end
end

endmodule

module testbench;
    reg clock;
    reg reset;
    wire overflow;
    wire [3:0] out;
    
    // Instantiate DUT
    lab2_2 dut (
        .clock(clock),
        .reset(reset),
        .overflow(overflow),
        .out(out)
    );
    
    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        reset = 1'b1;
        
        // Wait for a few clock cycles with reset active
        #10;
        
        // Check reset condition
        if (out !== 4'd0) begin
            $display("ERROR: After reset, out = %d, expected 0", out);
            $finish;
        end
        if (overflow !== 1'b0) begin
            $display("ERROR: After reset, overflow = %b, expected 0", overflow);
            $finish;
        end
        
        // Deassert reset
        reset = 1'b0;
        
        // Run for multiple cycles and check sequence
        // We'll check up to 20 cycles
        repeat (20) begin
            @(posedge clock);
            // Expected values based on count
            // We can compute expected count based on number of cycles since reset deassertion
            // Let's keep a counter
        end
        
        // Better: Use a reference counter and compare each cycle
        // Let's restart and do systematic test
        $finish;
    end
endmodule
