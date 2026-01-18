// Verilog code that resulted in empty output
// Saved at: 2026-01-15T01:05:59.472445
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

module up_down_counter #(
    parameter WIDTH = 4
) (
    input ud,
    input clk,
    input rst,
    output [WIDTH-1:0] out
);
    reg [WIDTH-1:0] out_reg;
    assign out = out_reg;
    always @(posedge clk) begin
        if (rst) begin
            out_reg <= {WIDTH{1'b0}};
        end else if (ud) begin
            out_reg <= out_reg + 1;
        end else begin
            out_reg <= out_reg - 1;
        end
    end
endmodule

module testbench;
    reg ud;
    reg clk;
    reg rst;
    wire [2:0] out;
    up_down_counter #(.WIDTH(3)) dut ( .ud(ud), .clk(clk), .rst(rst), .out(out) );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    initial begin
        ud = 0;
        rst = 1;
        @(posedge clk);
        #1;
        rst = 0;
        @(posedge clk);
        ud = 1;
        repeat (10) @(posedge clk);
        $finish;
    end
endmodule
