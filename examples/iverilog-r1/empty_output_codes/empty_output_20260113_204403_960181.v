// Verilog code that resulted in empty output
// Saved at: 2026-01-13T20:44:03.960213
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

module SR_to_JK (
    input clk,
    input rst,
    input j,
    input k,
    output q,
    output qbar
);
reg q_reg;
wire S, R;
assign q = q_reg;
assign qbar = ~q_reg;
assign S = j & qbar;
assign R = k & qbar;
always @(posedge clk) begin
    if (rst) begin
        q_reg <= 1'b0;
    end else begin
        case ({S, R})
            2'b01: q_reg <= 1'b0; // reset
            2'b10: q_reg <= 1'b1; // set
            default: q_reg <= q_reg; // hold (both 0 or both 1)
        endcase
    end
end
endmodule

module testbench;
reg clk, rst, j, k;
wire q, qbar;

SR_to_JK dut (clk, rst, j, k, q, qbar);

initial begin
    clk = 0;
    rst = 0;
    j = 0;
    k = 0;
    // Reset test
    @(posedge clk);
    rst <= 1;
    @(posedge clk);
    rst <= 0;
    // Now test JK combinations
    // Start with known state (after reset q=0)
    // Test J=0,K=0: hold
    @(posedge clk);
    j <= 0; k <= 0;
    @(posedge clk);
    // Expect q=0, qbar=1
    if (q !== 1'b0 || qbar !== 1'b1) begin
        $display("ERROR: Hold case failed: q=%b, qbar=%b", q, qbar);
        $finish;
    end
    // Test J=1,K=0: set
    @(posedge clk);
    j <= 1; k <= 0;
    @(posedge clk);
    if (q !== 1'b1 || qbar !== 1'b0) begin
        $display("ERROR: Set case failed: q=%b, qbar=%b", q, qbar);
        $finish;
    end
    // Test J=0,K=1: reset
    @(posedge clk);
    j <= 0; k <= 1;
    @(posedge clk);
    if (q !== 1'b0 || qbar !== 1'b1) begin
        $display("ERROR: Reset case failed: q=%b, qbar=%b", q, qbar);
        $finish;
    end
    // Test J=1,K=1: toggle (current q=0 -> should become 1)
    @(posedge clk);
    j <= 1; k <= 1;
    @(posedge clk);
    if (q !== 1'b1 || qbar !== 1'b0) begin
        $display("ERROR: Toggle from 0 to 1 case failed: q=%b, qbar=%b", q, qbar);
        $finish;
    end
    // Now toggle again (q=1 -> should become 0)
    @(posedge clk);
    j <= 1; k <= 1;
    @(posedge clk);
    if (q !== 1'b0 || qbar !== 1'b1) begin
        $display("ERROR: Toggle from 1 to 0 case failed: q=%b, qbar=%b", q, qbar);
        $finish;
    end
    // Additional test: after reset in middle of operation
    @(posedge clk);
    j <= 1; k <= 0; // set
    @(posedge clk);
    j <= 0; k <= 1; // reset
    @(posedge clk);
    rst <= 1;
    @(posedge clk);
    if (q !== 1'b0 || qbar !== 1'b1) begin
        $display("ERROR: Reset during operation failed: q=%b, qbar=%b", q, qbar);
        $finish;
    end
    $display("All tests passed!");
    $finish;
end

endmodule
