// Verilog code that resulted in empty output
// Saved at: 2026-01-07T01:54:09.039761
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

// Modulo-M counter
module modulo_m_counter #(
    parameter N = 4,
    parameter M = 16
) (
    input clk,
    input rst,
    output max_tick,
    output [N-1:0] q
);

    reg [N-1:0] count_reg;

    wire [N-1:0] next_count;
    wire max_tick_reg;

    assign next_count = (count_reg == M-1) ? {N{1'b0}} : count_reg + 1'b1;
    assign max_tick_reg = (count_reg == M-1);

    assign max_tick = max_tick_reg;
    assign q = count_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count_reg <= {N{1'b0}};
        end else begin
            count_reg <= next_count;
        end
    end

endmodule

// Minimal testbench
module testbench;
    reg clk;
    reg rst;
    wire max_tick;
    wire [2:0] q;  // 3 bits for M=5 (0-4)
    
    modulo_m_counter #(.N(3), .M(5)) dut (.clk(clk), .rst(rst), .max_tick(max_tick), .q(q));
    
    // Clock
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        rst = 1;
        #20;
        rst = 0;
        #100;
        $finish;
    end
endmodule
