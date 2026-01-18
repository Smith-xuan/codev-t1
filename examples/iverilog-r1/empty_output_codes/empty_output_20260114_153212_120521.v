// Verilog code that resulted in empty output
// Saved at: 2026-01-14T15:32:12.120546
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

module flowing_light #(
    parameter COUNTER_MAX = 24'hffffff
) (
    input clk,
    input rst,
    output [15:0] led
);

reg [23:0] counter;
reg [15:0] led_state;

always @(posedge clk) begin
    if (rst) begin
        counter <= 0;
        led_state <= 16'h0001;
    end else begin
        counter <= counter + 1;
        if (counter == COUNTER_MAX) begin
            if (led_state == 16'h8000)
                led_state <= 16'h0001;
            else
                led_state <= led_state << 1;
        end
    end
end

assign led = led_state;

endmodule

module testbench;
    reg clk;
    reg rst;
    wire [15:0] led;
    
    // Instantiate with small counter max for faster simulation
    parameter SMALL_MAX = 24'h0003;
    flowing_light #(.COUNTER_MAX(SMALL_MAX)) dut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    integer cycle;
    reg [15:0] prev_led;
    
    initial begin
        clk = 0;
        rst = 1;
        prev_led = 16'h0000;
        
        // Apply reset for 2 clock cycles
        #10 rst = 0;
        
        // Let simulation run for many cycles
        #2000 $finish;
    end
    
    // Monitor changes
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (cycle > 1) begin
            $display("Cycle %0d: led = 16'h%4h (binary: %0b)", cycle, led, led);
        end
        prev_led <= led;
    end
    
endmodule
