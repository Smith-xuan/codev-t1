// Verilog code that resulted in empty output
// Saved at: 2026-01-06T23:58:09.935866
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

module controllerHdl_Detect_Change (
    input  wire        CLK_IN,
    input  wire        reset,
    input  wire        enb_1_2000_0,
    input  wire [17:0] x,
    output reg         y
);
    reg [17:0] delay_reg;
    
    always @(posedge CLK_IN) begin
        if (reset) begin
            delay_reg <= 0;
            y         <= 0;
        end else begin
            if (enb_1_2000_0) begin
                delay_reg <= x;
                y         <= (x != delay_reg);
            end else begin
                y         <= 1'b0;
            end
        end
    end
endmodule

module testbench;
    reg CLK_IN;
    reg reset;
    reg enb_1_2000_0;
    reg [17:0] x;
    wire y;
    
    controllerHdl_Detect_Change dut (.CLK_IN(CLK_IN), .reset(reset), .enb_1_2000_0(enb_1_2000_0), .x(x), .y(y));
    
    always #5 CLK_IN = ~CLK_IN;
    
    initial begin
        CLK_IN = 0;
        reset = 1;
        enb_1_2000_0 = 0;
        x = 0;
        #10 reset = 0;
        #10 enb_1_2000_0 = 1;
        x = 18'h12345;
        #20 enb_1_2000_0 = 0;
        #10 $finish;
    end
endmodule
