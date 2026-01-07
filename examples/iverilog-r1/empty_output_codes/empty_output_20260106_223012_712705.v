// Verilog code that resulted in empty output
// Saved at: 2026-01-06T22:30:12.712743
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

module Forwardunit (
    input [4:0] EX_Rs,
    input [4:0] EX_Rt,
    input MEM_regwrite,
    input [4:0] MEM_writereg,
    input WB_regwrite,
    input [4:0] WB_writereg,
    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB
);
    always @(*) begin
        ForwardA = 2'd0;
        if (MEM_regwrite && (MEM_writereg != 5'b0) && (MEM_writereg == EX_Rs)) 
            ForwardA = 2'd1;
        else if (WB_regwrite && (WB_writereg != 5'b0) && (WB_writereg == EX_Rs))
            ForwardA = 2'd2;
    end
    
    always @(*) begin
        ForwardB = 2'd0;
        if (MEM_regwrite && (MEM_writereg != 5'b0) && (MEM_writereg == EX_Rt)) 
            ForwardB = 2'd1;
        else if (WB_regwrite && (WB_writereg != 5'b0) && (WB_writereg == EX_Rt))
            ForwardB = 2'd2;
    end
endmodule

module testbench;
    // Just a dummy testbench to compile
    reg [4:0] EX_Rs, EX_Rt;
    reg MEM_regwrite, WB_regwrite;
    reg [4:0] MEM_writereg, WB_writereg;
    wire [1:0] ForwardA, ForwardB;
    
    Forwardunit dut (.*);
endmodule
