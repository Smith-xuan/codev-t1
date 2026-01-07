// Verilog code that resulted in empty output
// Saved at: 2026-01-07T02:47:41.006715
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

`timescale 1ns/1ns

module RING_COUNTER (
    input clk,
    input rst,
    output t0,
    output t1,
    output t2,
    output t3
);

reg [3:0] state;

always @(posedge clk) begin
    if (rst) state <= 4'b1000;
    else state <= {state[0], state[3:1]};
end

assign t0 = state[3];
assign t1 = state[2];
assign t2 = state[1];
assign t3 = state[0];

endmodule

module testbench;
reg clk, rst;
wire t0, t1, t2, t3;

RING_COUNTER dut (clk, rst, t0, t1, t2, t3);

initial begin
    clk = 0;
    rst = 1;
    
    // Open VCD dump file for waveform viewing (optional)
    // $dumpfile("ring_counter.vcd");
    // $dumpvars(0, testbench);
    
    // Verify reset state
    #10; // Wait for clock edge? Let's wait a bit
    // Check outputs after reset is applied (synchronous reset, so after posedge with rst=1)
    // We'll apply reset then wait for posedge
    @(posedge clk);
    #1; // small delay after edge to allow state update
    if (t0 !== 1'b1 || t1 !== 1'b0 || t2 !== 1'b0 || t3 !== 1'b0) begin
        $display("ERROR: After reset, expected t0=1, others 0. Got t0=%b, t1=%b, t2=%b, t3=%b", t0, t1, t2, t3);
        $finish;
    end else begin
        $display("PASS: Reset state correct.");
    end
    
    // Release reset
    rst = 0;
    
    // Test sequence: 4 cycles after reset release
    repeat (4) begin
        @(posedge clk);
        #1;
        // Check that only one output is high
        if ((t0 + t1 + t2 + t3) !== 1) begin
            $display("ERROR: Multiple outputs high at time %0t: t0=%b, t1=%b, t2=%b, t3=%b", $time, t0, t1, t2, t3);
            $finish;
        end
    end
    
    // After 4 cycles, we should be back to t0=1
    @(posedge clk);
    #1;
    if (t0 !== 1'b1 || t1 !== 1'b0 || t2 !== 1'b0 || t3 !== 1'b0) begin
        $display("ERROR: After 4 cycles, expected back to t0=1, others 0. Got t0=%b, t1=%b, t2=%b, t3=%b", t0, t1, t2, t3);
        $finish;
    end else begin
        $display("PASS: Ring counter cycle completed correctly.");
    end
    
    // Additional test: verify sequence explicitly
    rst = 1;
    @(posedge clk);
    #1;
    if (t0 !== 1'b1) $display("FAIL: Reset t0");
    rst = 0;
    // Wait for t1
    @(posedge clk);
    #1;
    if (t0 !== 1'b0 || t1 !== 1'b1) $display("FAIL: t1 not high");
    @(posedge clk);
    #1;
    if (t1 !== 1'b0 || t2 !== 1'b1) $display("FAIL: t2 not high");
    @(posedge clk);
    #1;
    if (t2 !== 1'b0 || t3 !== 1'b1) $display("FAIL: t3 not high");
    @(posedge clk);
    #1;
    if (t3 !== 1'b0 || t0 !== 1'b1) $display("FAIL: back to t0 not high");
    
    $display("All tests passed.");
    $finish;
end

endmodule
