// Verilog code that resulted in empty output
// Saved at: 2026-01-14T23:09:15.131500
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

module timer #(parameter RCWIDTH = 25) (
    input clk,
    input rst,
    output en
);
    reg [RCWIDTH-1:0] counter;

    always @(posedge clk) begin
        if (rst) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end

    assign en = (counter == 0);
endmodule

module testbench;
    reg clk;
    reg rst;
    wire en;
    
    timer dut (.clk(clk), .rst(rst), .en(en));
    
    initial begin
        clk = 0;
        rst = 1;
        #10 clk = 1;
        #10 clk = 0;
        
        // Check after reset
        @(posedge clk);
        #1 $display("After reset: rst=%0d, counter=%0d, en=%0d", rst, dut.counter, en);
        
        // Deassert reset
        rst = 0;
        @(posedge clk);
        #1 $display("Cycle 1: rst=%0d, counter=%0d, en=%0d", rst, dut.counter, en);
        @(posedge clk);
        #1 $display("Cycle 2: rst=%0d, counter=%0d, en=%0d", rst, dut.counter, en);
        @(posedge clk);
        #1 $display("Cycle 3: rst=%0d, counter=%0d, en=%0d", rst, dut.counter, en);
        
        // Assert reset again
        rst = 1;
        @(posedge clk);
        #1 $display("Reset asserted: rst=%0d, counter=%0d, en=%0d", rst, dut.counter, en);
        
        // End simulation
        #10 $finish;
    end
endmodule
