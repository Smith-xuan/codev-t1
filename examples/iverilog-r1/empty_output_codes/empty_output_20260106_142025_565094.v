// Verilog code that resulted in empty output
// Saved at: 2026-01-06T14:20:25.565122
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

module systolic_array_pe #(
    parameter input_width = 8
) (
    input wire clk,
    input wire reset,
    input wire [input_width-1:0] in_a,
    input wire [input_width-1:0] in_b,
    output reg [input_width-1:0] out_a,
    output reg [input_width-1:0] out_b,
    output reg [2*input_width-1:0] out_c
);

    always @(posedge clk) begin
        if (reset) begin
            out_a <= {input_width{1'b0}};
            out_b <= {input_width{1'b0}};
            out_c <= {2*input_width{1'b0}};
        end else begin
            out_a <= in_a;
            out_b <= in_b;
            out_c <= out_c + (in_a * in_b);
        end
    end

endmodule

module testbench;
    reg clk;
    reg reset;
    reg [7:0] in_a;
    reg [7:0] in_b;
    wire [7:0] out_a;
    wire [7:0] out_b;
    wire [15:0] out_c;
    
    systolic_array_pe #(.input_width(8)) dut (.*);
    
    // Clock generation
    initial begin
        clk = 0;
        #100 $finish;
    end
    
    always #5 clk = ~clk;
    
    // Stimulus
    initial begin
        reset = 1;
        in_a = 0;
        in_b = 0;
        #20;
        reset = 0;
        #100;
    end
    
endmodule
