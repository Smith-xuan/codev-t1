// Verilog code that resulted in empty output
// Saved at: 2026-01-06T04:41:49.641515
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

module mod_m_counter #(
    parameter N = 8,  // Width of counter in bits
    parameter M = 256 // Modulus, value from 0 to M-1
) (
    input wire clk,
    input wire reset,
    output reg max_tick,
    output reg [N-1:0] q
);

    // Maximum value representable with N bits
    localparam MAX_REPRESENTABLE = (1 << N) - 1;
    
    // Safety check: if M > MAX_REPRESENTABLE, counter will wrap at 2^N instead
    // In simulation, print warning
    initial begin
        if (M > MAX_REPRESENTABLE) begin
            $display("Warning: M (%0d) > 2^N (%0d). Counter will wrap at 2^N, not at M-1.", 
                     M, MAX_REPRESENTABLE);
        end
    end
    
    // Compute M_minus_1 as N-bit value (wraps if M > MAX_REPRESENTABLE)
    wire [N-1:0] M_minus_1 = (M - 1);
    
    // Counter logic
    always @(posedge clk) begin
        if (reset) begin
            q <= {N{1'b0}};
        end else begin
            if (q == M_minus_1) begin
                // Reached maximum value for this modulus
                q <= {N{1'b0}};
            end else begin
                q <= q + 1'b1;
            end
        end
    end
    
    // max_tick generation
    always @(*) begin
        max_tick = (q == M_minus_1);
    end
    
endmodule

// Minimal testbench to verify basic functionality
module testbench;
    reg clk;
    reg reset;
    wire max_tick;
    wire [3:0] q;  // N=4
    
    // Instance with N=4, M=10 (count 0-9)
    mod_m_counter #(.N(4), .M(10)) dut (clk, reset, max_tick, q);
    
    // Generate clock pulses (limited to 50 cycles)
    initial begin
        clk = 0;
        repeat (50) #5 clk = ~clk;
    end
    
    // Test stimulus and checking
    integer errors = 0;
    reg [3:0] expected_q = 0;
    
    initial begin
        // Initialize
        reset = 1;
        #2;  // Wait a bit before first clock edge
        @(posedge clk);
        #1;
        reset = 0;
        
        // Track 25 cycles after reset
        repeat (25) begin
            @(posedge clk);
            #1;  // Wait for signals to settle
            
            // Update expected value: count 0-9, wrap
            if (expected_q == 9) expected_q = 0;
            else expected_q = expected_q + 1;
            
            // Check q
            if (q !== expected_q) begin
                $display("ERROR at time %0t: q = %d, expected = %d", 
                         $time, q, expected_q);
                errors = errors + 1;
            end
            
            // Check max_tick
            if ((expected_q == 9) !== max_tick) begin
                $display("ERROR at time %0t: max_tick = %b, expected = %b for q=%d",
                         $time, max_tick, (expected_q == 9), expected_q);
                errors = errors + 1;
            end
        end
        
        // Test reset in middle of counting
        reset = 1;
        #1;
        @(posedge clk);
        #1;
        reset = 0;
        expected_q = 0;
        
        repeat (10) begin
            @(posedge clk);
            #1;
            if (expected_q == 9) expected_q = 0;
            else expected_q = expected_q + 1;
            
            if (q !== expected_q) begin
                $display("ERROR after reset: q = %d, expected = %d", q, expected_q);
                errors = errors + 1;
            end
        end
        
        // Summary
        if (errors == 0) begin
            $display("PASS: All tests passed");
        end else begin
            $display("FAIL: %d errors", errors);
        end
        
        $finish;
    end
    
endmodule
