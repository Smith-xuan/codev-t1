// Verilog code that resulted in empty output
// Saved at: 2026-01-14T07:19:41.256729
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

module lfsr_4bit (
    input clk,
    input rst,
    output q0,
    output q1,
    output q2,
    output q3
);

wire feedback;
assign feedback = q3 ^ ~q0;

reg q0_r, q1_r, q2_r, q3_r;
assign q0 = q0_r;
assign q1 = q1_r;
assign q2 = q2_r;
assign q3 = q3_r;

always @(posedge clk) begin
    if (rst) begin
        q0_r <= 1'b0;
        q1_r <= 1'b0;
        q2_r <= 1'b0;
        q3_r <= 1'b0;
    end else begin
        q0_r <= q3_r;
        q1_r <= feedback;
        q2_r <= q1_r;
        q3_r <= q2_r;
    end
end

endmodule

module testbench;
    reg clk;
    reg rst;
    wire q0, q1, q2, q3;
    
    lfsr_4bit dut (clk, rst, q0, q1, q2, q3);
    
    initial begin
        clk = 0;
        rst = 1;
        // wait for first rising edge
        @(posedge clk);
        #1; // small delay after edge
        $display("After reset: state = %b %b %b %b", q0, q1, q2, q3);
        rst = 0;
        // run 10 cycles
        repeat (10) begin
            @(posedge clk);
            #1;
            $display("State after clock: %b %b %b %b", q0, q1, q2, q3);
        end
        $finish;
    end
endmodule
