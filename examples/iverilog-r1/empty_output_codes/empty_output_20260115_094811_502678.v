// Verilog code that resulted in empty output
// Saved at: 2026-01-15T09:48:11.502723
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

module Div10Toggle (
    input clk,
    output reg out
);
    reg [3:0] count = 0;
    wire toggle_en;
    
    always @(posedge clk) begin
        if (count == 4'd9) begin
            count <= 4'd0;
        end else begin
            count <= count + 4'd1;
        end
    end
    
    assign toggle_en = (count == 4'd9);
    
    always @(posedge clk) begin
        if (toggle_en) begin
            out <= ~out;
        end
    end
endmodule

module testbench;
    reg clk;
    wire out;
    
    Div10Toggle dut (.clk(clk), .out(out));
    
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    integer last_rise = 0;
    always @(posedge out) begin
        $display("Rise at %0t ns, period = %0t ns", $time, $time - last_rise);
        last_rise = $time;
    end
    
    initial #200 $finish;
endmodule
