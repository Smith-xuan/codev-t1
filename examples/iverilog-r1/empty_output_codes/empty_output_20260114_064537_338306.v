// Verilog code that resulted in empty output
// Saved at: 2026-01-14T06:45:37.338348
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

`timescale 1ns / 1ps

module pulse #(
    parameter PERIOD = 10,
    parameter PULSE_WIDTH = 3
) (
    input wire clk,
    output reg out
);

reg [31:0] count;

initial begin
    count = 0;
    out = 0;
end

always @(posedge clk) begin
    if (count == PERIOD) begin
        out <= 1'b1;
        count <= 0;
    end else if (out && count == PULSE_WIDTH) begin
        out <= 1'b0;
        // count not reset, continue counting
    end else begin
        count <= count + 1;
    end
end

endmodule

module testbench;
    reg clk;
    wire out;
    
    pulse #(.PERIOD(10), .PULSE_WIDTH(3)) dut (.clk(clk), .out(out));
    
    initial begin
        clk = 0;
        #130 $finish;
    end
    
    always #5 clk = ~clk;
endmodule
