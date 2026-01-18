// Verilog code that resulted in empty output
// Saved at: 2026-01-15T06:42:58.101279
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

module led_blinking #(
  parameter COUNT_MAX = 10_000_000 - 1
)(
  input clck,
  input reset,
  output [3:0] led
);
  reg [23:0] counter;
  reg [3:0] led_reg;

  always @(posedge clck) begin
    if (reset) begin
      counter <= 0;
      led_reg <= 4'b0000;
    end else begin
      if (counter == COUNT_MAX) begin
        counter <= 0;
        led_reg <= ~led_reg;
      end else begin
        counter <= counter + 1;
      end
    end
  end

  assign led = led_reg;
endmodule

module testbench;
  reg clck;
  reg reset;
  wire [3:0] led;
  
  // Instantiate with a small count for simulation
  led_blinking #(.COUNT_MAX(5)) dut (
    .clck(clck),
    .reset(reset),
    .led(led)
  );
  
  initial begin
    clck = 0;
    reset = 0;
    
    // Test reset
    reset = 1;
    @(posedge clck);
    reset = 0;
    
    // Monitor
    $display("Time\tCounter\tLED");
    $monitor("%0d\t\d\t%b", $time, dut.counter, led);
    
    // Run for 30 clock cycles
    repeat (30) begin
      @(posedge clck);
    end
    
    $finish;
  end
endmodule
