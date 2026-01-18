// Verilog code that resulted in empty output
// Saved at: 2026-01-15T08:55:58.848052
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

module oneShot #(
    parameter SHIFT = 2
) (
    input sigIn,
    input clk,
    output sigOut
);
    reg [SHIFT-1:0] shift_reg;
    
    always @(posedge clk) begin
        if (SHIFT == 1) begin
            shift_reg <= sigIn;
        end else begin
            shift_reg <= {sigIn, shift_reg[SHIFT-1:1]};
        end
    end
    
    wire [SHIFT-1:0] pattern = (1 << (SHIFT-1));
    assign sigOut = (shift_reg == pattern);
    
endmodule

module testbench;
    // Test with SHIFT = 2
    reg sigIn;
    reg clk;
    wire sigOut;
    
    oneShot #(.SHIFT(2)) dut (.sigIn(sigIn), .clk(clk), .sigOut(sigOut));
    
    initial begin
        clk = 0;
        sigIn = 0;
        #10;
        // Test rising edge detection
        sigIn = 1;
        #10;
        sigIn = 0;
        #30;
        $finish;
    end
    
    always #5 clk = ~clk;
endmodule
