// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:08:05.183282
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

module one_pulse (
    output reg out_pulse,
    input in_trig,
    input clk,
    input rst
);
    reg trig_r;
    
    always @(posedge clk) begin
        if (rst) begin
            trig_r <= 1'b0;
            out_pulse <= 1'b0;
        end else begin
            trig_r <= in_trig;
            out_pulse <= in_trig && !trig_r;
        end
    end
endmodule

module testbench;
    reg clk;
    reg rst;
    reg in_trig;
    wire out_pulse;
    
    one_pulse dut (.*);
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst = 1;
        in_trig = 0;
        #30;
        rst = 0;
        #10 in_trig = 1;
        #10 in_trig = 0;
        #50 $finish;
    end
endmodule
