// Verilog code that resulted in empty output
// Saved at: 2026-01-14T00:23:04.512209
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

`timescale 1ns/1ps

module tick_10ms (
    input clk,
    input rst,
    output tick
);

reg [19:0] counter;

always @(posedge clk) begin
    if (rst) begin
        counter <= 20'b0;
    end else begin
        if (counter == 20'd999_999) begin
            counter <= 20'b0;
        end else begin
            counter <= counter + 1'b1;
        end
    end
end

assign tick = (counter == 20'd999_999);

endmodule

module testbench;
    reg clk;
    reg rst;
    wire tick;
    
    tick_10ms dut (.clk(clk), .rst(rst), .tick(tick));
    
    // Clock generation: 100 MHz => period = 10 ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns period
    end
    
    initial begin
        // Initialize signals
        rst = 1'b1;
        // Release reset after some time
        #100 rst = 1'b0;
        // Wait for a few milliseconds
        #10000000; // 10 ms simulation (i.e., about 1000000 clock cycles)
        $finish;
    end
    
endmodule
