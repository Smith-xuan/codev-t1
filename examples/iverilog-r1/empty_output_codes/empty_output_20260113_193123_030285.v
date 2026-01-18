// Verilog code that resulted in empty output
// Saved at: 2026-01-13T19:31:23.030316
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

module pix_ticker (
  input clk,
  input reset,
  output tick
);

  reg [17:0] counter;
  reg tick_reg;

  always @(posedge clk) begin
    if (reset) begin
      counter <= 0;
    end else if (counter == 18'd208333) begin
      counter <= 0;
    end else begin
      counter <= counter + 1;
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      tick_reg <= 0;
    end else if (counter == 18'd208333) begin
      tick_reg <= 1;
    end else begin
      tick_reg <= 0;
    end
  end

  assign tick = tick_reg;

endmodule

module testbench;
  reg clk;
  reg reset;
  wire tick;

  pix_ticker dut (.clk(clk), .reset(reset), .tick(tick));

  // Clock generation
  always #5 clk = ~clk;

  initial begin
    clk = 0;
    reset = 1;
    #20;
    reset = 0;
    #10000;
    $finish;
  end

  // Monitor tick occurrences
  integer tick_count = 0;
  integer last_tick_time = 0;
  integer period_cycles = 0;
  always @(posedge tick) begin
    tick_count = tick_count + 1;
    if (last_tick_time != 0) begin
      period_cycles = ($time - last_tick_time) / 10; // clock period = 10 time units
    end
    last_tick_time = $time;
    $display("Tick %0d at time %0t, period = %0d cycles", tick_count, $time, period_cycles);
  end

endmodule
