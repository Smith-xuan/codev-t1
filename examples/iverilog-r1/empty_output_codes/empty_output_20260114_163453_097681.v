// Verilog code that resulted in empty output
// Saved at: 2026-01-14T16:34:53.097710
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

module pwm (
    input clk,
    output speaker
);

reg [23:0] counter = 24'd0;
reg [9:0] hz = 10'd0;
wire rising_edge = (counter == 24'h7FFFFF);

always @(posedge clk) begin
    counter <= counter + 24'd1;
    if (rising_edge) begin
        if (hz == 10'd1023)
            hz <= 10'd0;
        else
            hz <= hz + 24'd1;
    end
end

assign speaker = counter[23];

endmodule

module testbench;
reg clk;
wire speaker;

pwm dut (.clk(clk), .speaker(speaker));

initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10 ns period (100 MHz)
end

integer cycle_count;
initial begin
    cycle_count = 0;
    forever @(posedge clk) cycle_count = cycle_count + 1;
end

// Monitor for speaker rising edges
reg prev_speaker;
always @(posedge clk) begin
    prev_speaker <= speaker;
    if (prev_speaker == 0 && speaker == 1) begin
        $display("Rising edge detected at time %0t, cycle %0d", $time, cycle_count);
        $display("  counter = %h, hz = %d", dut.counter, dut.hz);
    end
end

initial begin
    #1000; // simulate for 1000 ns (50 cycles)
    $finish;
end

endmodule
