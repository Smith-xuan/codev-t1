// Verilog code that resulted in empty output
// Saved at: 2026-01-06T02:47:34.454453
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

// contador2: 1-bit toggle counter with reset when output is 1
module contador2 (
    input CLK,
    input RESET,
    output reg RESULT
);
    always @(posedge CLK) begin
        if (!RESET) begin
            RESULT <= 1'b0;
        end else if (RESULT == 1'b1) begin
            RESULT <= 1'b0;
        end else begin
            RESULT <= 1'b1;
        end
    end
endmodule

// contador32: 5-bit counter 0-31 with enable and reset
module contador32 (
    input CLK,
    input RESET,
    input ENB,
    output reg [4:0] RESULT
);
    always @(posedge CLK) begin
        if (!RESET) begin
            RESULT <= 5'b0;
        end else if (RESULT == 5'd31) begin
            RESULT <= 5'b0;
        end else if (ENB) begin
            RESULT <= RESULT + 1;
        end
    end
endmodule

// Minimal testbench
module testbench;
    reg clk;
    reg reset_;
    reg enb;
    
    wire result2;
    wire [4:0] result32;
    
    contador2 uut2 (.CLK(clk), .RESET(reset_), .RESULT(result2));
    contador32 uut32 (.CLK(clk), .RESET(reset_), .ENB(enb), .RESULT(result32));
    
    // Clock
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Stimulus
    initial begin
        reset_ = 0;
        enb = 0;
        #10;
        reset_ = 1;
        #5;
        enb = 1;
        #50;
        $finish;
    end
endmodule
