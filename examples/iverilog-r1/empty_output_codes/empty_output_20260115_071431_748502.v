// Verilog code that resulted in empty output
// Saved at: 2026-01-15T07:14:31.748534
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

module xorshift32 (
    input clk,
    input rst,
    input [31:0] seed,
    output [31:0] res
);

reg [31:0] state_reg;

wire [31:0] t1, t2, t3;

assign t1 = state_reg ^ (state_reg << 13);
assign t2 = t1 ^ (t1 >> 17);
assign t3 = t2 ^ (t2 << 5);

wire [31:0] state_next = t3;

always @(posedge clk) begin
    if (rst) begin
        state_reg <= seed;
    end else begin
        state_reg <= state_next;
    end
end

assign res = state_reg;

endmodule

module testbench;
reg clk = 0;
reg rst;
reg [31:0] seed;
wire [31:0] res;

xorshift32 dut (clk, rst, seed, res);

initial begin
    // Test 1: simple known value
    seed = 32'h12345678;
    rst = 1;
    @(posedge clk);
    rst = 0;
    $display("Seed = %h", seed);
    $display("State after reset = %h", dut.state_reg);
    
    repeat (10) begin
        @(posedge clk);
        $display("Random = %h", res);
    end
end

endmodule
