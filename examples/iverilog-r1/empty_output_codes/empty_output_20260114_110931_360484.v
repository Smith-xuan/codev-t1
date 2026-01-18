// Verilog code that resulted in empty output
// Saved at: 2026-01-14T11:09:31.360519
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

module FIFO(
    input [3:0] data_in,
    input clk,
    input rst,
    output [3:0] data_out
);

reg [3:0] first, second, third, fourth;

always @(posedge clk) begin
    if (rst) begin
        first <= 4'b0;
        second <= 4'b0;
        third <= 4'b0;
        fourth <= 4'b0;
    end else begin
        first <= data_in;
        second <= first;
        third <= second;
        fourth <= third;
    end
end

assign data_out = fourth;

endmodule

module testbench;
    reg [3:0] data_in;
    reg clk, rst;
    wire [3:0] data_out;
    
    FIFO dut (.data_in(data_in), .clk(clk), .rst(rst), .data_out(data_out));
    
    initial begin
        clk = 0;
        rst = 1;
        data_in = 4'b0000;
        
        // Apply reset for two cycles
        #10 rst = 0;
        
        // Test sequence
        // Clock 1: input A
        @(posedge clk)
        data_in = 4'b1010;
        @(posedge clk)
        data_in = 4'b0101;
        @(posedge clk)
        data_in = 4'b1110;
        @(posedge clk)
        data_in = 4'b0011;
        
        // Wait for output to appear
        @(posedge clk)
        $display("Time %0t: data_out = %b", $time, data_out);
        
        // Continue for a few more cycles
        repeat (5) @(posedge clk);
        
        $finish;
    end
endmodule
