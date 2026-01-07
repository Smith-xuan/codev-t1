// Verilog code that resulted in empty output
// Saved at: 2026-01-07T08:59:21.353160
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

module Light (
    input in_key,
    output out_key,
    input clk,
    input clr
);

reg delay1, delay2, delay3;

always @(posedge clk or posedge clr) begin
    if (clr) begin
        delay1 <= 1'b0;
        delay2 <= 1'b0;
        delay3 <= 1'b0;
    end else begin
        delay1 <= ~in_key;  // invert input and store
        delay2 <= delay1;
        delay3 <= delay2;
    end
end

assign out_key = delay1 & delay2 & delay3;

endmodule

module testbench;
    reg in_key;
    reg clk;
    reg clr;
    wire out_key;
    
    Light dut (.in_key(in_key), .out_key(out_key), .clk(clk), .clr(clr));
    
    integer cycles;
    
    initial begin
        // Generate clock (10 periods)
        for (cycles = 0; cycles < 10; cycles = cycles + 1) begin
            #5 clk = 1;
            #5 clk = 0;
        end
    end
    
    initial begin
        // Initialize
        in_key = 0;
        clr = 0;
        
        // Wait a bit
        #2;
        
        // Test 1: Reset
        clr = 1;
        #10;
        clr = 0;
        #2;
        
        if (out_key !== 0) begin
            $display("FAIL: out_key not 0 after reset");
            $finish;
        end
        
        // Provide three zeros
        in_key = 0;
        #10; // first posedge after reset (actually this is half period later)
        // We need to wait for posedge; let's just wait for next posedge by timing.
        // Since we toggled clk in clock generation initial block, need to synchronize.
        // Let's wait for next posedge by detecting clk==1 then wait for edge.
        // Simpler: we'll manually control clock with a separate process in testbench.
        // But we already have clock generation; let's just use posedge timing.
        // We'll use @(posedge clk) in testbench.
        // However, we already have a clock generation that will stop after 10 cycles.
        // The stimulus will need to complete within those cycles.
        // Let's restart with a simpler approach: use a single initial block with both clock and stimulus.
        $finish;
    end
endmodule
