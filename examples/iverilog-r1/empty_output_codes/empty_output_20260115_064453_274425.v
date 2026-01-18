// Verilog code that resulted in empty output
// Saved at: 2026-01-15T06:44:53.274460
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
  
  // Instantiate with a small count for simulation (N=5 cycles between toggles)
  led_blinking #(.COUNT_MAX(4)) dut (
    .clck(clck),
    .reset(reset),
    .led(led)
  );
  
  reg [23:0] edge_count;
  reg [3:0] prev_led;
  integer cycle_count;
  
  initial begin
    clck = 0;
    reset = 0;
    edge_count = 0;
    cycle_count = 0;
    prev_led = led;
    
    // Apply reset at time 0
    reset = 1;
    @(posedge clck);
    reset = 0;
    
    // Wait a bit after reset
    @(posedge clck);
    
    $display("Starting simulation with COUNT_MAX = %0d (should toggle every %0d cycles)", 4, 5);
    $display("Time\tEdge\tLED\tCycleCount\tCounter");
    
    // Run for 30 clock edges
    for (integer i = 0; i < 30; i = i + 1) begin
      @(posedge clck);
      edge_count = edge_count + 1;
      #1; // slight delay to observe values after clock edge
      $display("%0d\t%d\t%b\t%0d\t%0d", $time, edge_count, led, dut.counter, i);
      
      // Check reset
      if (reset) begin
        $display("Reset detected at edge %0d", edge_count);
      end
      
      // Check toggling pattern
      if (led !== prev_led) begin
        $display("LED toggled at edge %0d", edge_count);
        cycle_count = cycle_count + 1; // count toggle events
        // Check that toggle occurs at expected cycle count (multiple of 5)
        if (cycle_count % 5 != 0) begin
          $error("Toggle unexpected at edge %0d (should occur every 5 edges)", edge_count);
        end
      end
      prev_led = led;
    end
    
    $display("Simulation finished.");
    $finish;
  end
endmodule
