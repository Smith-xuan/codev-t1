// Verilog code that resulted in empty output
// Saved at: 2026-01-07T03:59:54.075646
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

module Register_file(
    input clk,
    input rst,
    input [4:0] Src1,
    input [4:0] Src2,
    input [4:0] Dest,
    input [31:0] Write_Val,
    input Write_EN,
    output [31:0] Reg1,
    output [31:0] Reg2
);

    reg [31:0] rf [0:31];
    integer i;
    
    always @(negedge clk) begin
        if (rst) begin
            // Initialize all registers to their index values (0-31)
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= i;
            end
        end
        else if (Write_EN && Dest != 5'b0) begin
            // Write only when enabled and destination is not zero register
            rf[Dest] <= Write_Val;
        end
    end
    
    assign Reg1 = (Src1 == 5'b0) ? 32'b0 : rf[Src1];
    assign Reg2 = (Src2 == 5'b0) ? 32'b0 : rf[Src2];
    
endmodule

module testbench;
    reg clk;
    reg rst;
    reg [4:0] Src1;
    reg [4:0] Src2;
    reg [4:0] Dest;
    reg [31:0] Write_Val;
    reg Write_EN;
    wire [31:0] Reg1;
    wire [31:0] Reg2;
    
    Register_file dut (.*);
    
    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst = 1;
        @(negedge clk);
        rst = 0;
        @(negedge clk);
        
        // Check a few registers
        Src1 = 0; #1; if (Reg1 !== 0) $finish;
        Src1 = 5; #1; if (Reg1 !== 5) $finish;
        Src1 = 7; #1; if (Reg1 !== 7) $finish;
        
        // Write to register 7
        @(negedge clk);
        Dest = 7;
        Write_Val = 32'h77777777;
        Write_EN = 1;
        @(negedge clk);
        Write_EN = 0;
        Src1 = 7; #1; if (Reg1 !== 32'h77777777) $finish;
        
        // Write to zero register ignored
        @(negedge clk);
        Dest = 0;
        Write_Val = 32'hDEADBEEF;
        Write_EN = 1;
        @(negedge clk);
        Write_EN = 0;
        Src1 = 0; #1; if (Reg1 !== 0) $finish;
        
        $display("All tests passed");
        $finish;
    end
endmodule
