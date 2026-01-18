// Verilog code that resulted in empty output
// Saved at: 2026-01-15T06:29:14.887788
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

`timescale 1ns / 1ps

module clk_make_wrong (
  input clk,
  input rst,
  output baud_clk
);
  parameter DIV_FACTOR = 250;
  localparam COUNTER_WIDTH = $clog2(DIV_FACTOR);
  reg [COUNTER_WIDTH-1:0] counter;
  reg baud;
  
  always @(posedge clk) begin
    if (rst) begin
      counter <= 0;
      baud <= 0;
    end else begin
      if (counter == DIV_FACTOR - 1) begin
        counter <= 0;
        baud <= ~baud;
      end else begin
        counter <= counter + 1;
      end
    end
  end
  
  assign baud_clk = baud;
endmodule

module clk_make_correct (
  input clk,
  input rst,
  output baud_clk
);
  parameter DIV_FACTOR = 250;
  localparam COUNTER_WIDTH = $clog2(DIV_FACTOR);
  reg [COUNTER_WIDTH-1:0] counter;
  reg baud;
  
  always @(posedge clk) begin
    if (rst) begin
      counter <= 0;
      baud <= 0;
    end else begin
      if (counter == (DIV_FACTOR / 2) - 1) begin
        counter <= 0;
        baud <= ~baud;
      end else begin
        counter <= counter + 1;
      end
    end
  end
  
  assign baud_clk = baud;
endmodule

module testbench;
  reg clk;
  reg rst;
  wire baud_w, baud_c;
  
  clk_make_wrong dut_w (.clk(clk), .rst(rst), .baud_clk(baud_w));
  clk_make_correct dut_c (.clk(clk), .rst(rst), .baud_clk(baud_c));
  
  initial begin
    clk = 0;
    rst = 1;
    #4 rst = 0;
    #500000 $finish;
  end
  
  always #4 clk = ~clk; // 125 MHz period 8 ns
  
  integer last_rise_w, last_rise_c;
  integer period_w, period_c;
  
  initial begin
    last_rise_w = 0;
    last_rise_c = 0;
    // Wait for both baud clocks to rise after reset
    @(posedge baud_w);
    last_rise_w = $time;
    @(posedge baud_c);
    last_rise_c = $time;
    // Wait for next rising edges
    @(posedge baud_w);
    period_w = $time - last_rise_w;
    $display("Wrong version (toggle at DIV-1): period = %0d ns", period_w);
    $display("  Expected for 500 kHz: 2000 ns");
    @(posedge baud_c);
    period_c = $time - last_rise_c;
    $display("Correct version (toggle at DIV/2-1): period = %0d ns", period_c);
    $display("  Expected for 500 kHz: 2000 ns");
    // Check if correct version matches expected
    if (period_c == 2000) begin
      $display("Correct version passes: period is 2000 ns (500 kHz).");
    end else begin
      $display("ERROR: Correct version period mismatch.");
    end
    // Check if wrong version matches expected
    if (period_w == 4000) begin
      $display("Wrong version passes: period is 4000 ns (250 kHz).");
    end else begin
      $display("ERROR: Wrong version period mismatch.");
    end
  end
endmodule
