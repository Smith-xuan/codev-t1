// Verilog code that resulted in empty output
// Saved at: 2026-01-14T14:08:44.955433
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

// Breathing LED module with PWM using 50 MHz clock
module led_breathe_display (
    input clk,
    input rst_n,
    output reg [7:0] led_data
);

    // Parameters for 50 MHz clock (period = 20 ns)
    localparam US_PERIOD = 50-1;  // Count 50 cycles for 1 us (0 to 49)
    localparam MS_PERIOD = 1000-1; // Count 1000 us for 1 ms (0 to 999)
    localparam SEC_MS = 1000;      // Milliseconds per second
    
    // Counters
    reg [5:0] us_counter;  // Microsecond counter (0 to 49)
    reg [9:0] ms_counter;  // Millisecond counter (0 to 999)
    reg [5:0] sec_counter; // Second counter (0 to 59)
    
    wire us_tick, ms_tick;
    
    // Generate ticks
    assign us_tick = (us_counter == US_PERIOD);
    assign ms_tick = (ms_counter == MS_PERIOD);
    
    // Counter updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            us_counter <= 0;
            ms_counter <= 0;
            sec_counter <= 0;
        end else begin
            // Microsecond counter
            if (us_counter == US_PERIOD) begin
                us_counter <= 0;
            end else begin
                us_counter <= us_counter + 1;
            end
            
            // Millisecond counter (increments on us_tick)
            if (us_tick) begin
                if (ms_counter == MS_PERIOD) begin
                    ms_counter <= 0;
                    // Increment second counter
                    if (sec_counter == 59) begin
                        sec_counter <= 0;
                    end else begin
                        sec_counter <= sec_counter + 1;
                    end
                end else begin
                    ms_counter <= ms_counter + 1;
                end
            end
        end
    end
    
    // Breathing pattern: triangle wave of brightness (0 to 255) with period 1 second
    // Increase for 500 ms, decrease for next 500 ms
    always @(*) begin
        if (ms_counter < SEC_MS/2) begin
            // Increasing phase
            led_data = (ms_counter * 255) / (SEC_MS/2);
        end else begin
            // Decreasing phase
            led_data = (SEC_MS - ms_counter) * 255 / (SEC_MS/2);
        end
    end
    
endmodule

// Testbench
module testbench;
    reg clk;
    reg rst_n;
    wire [7:0] led_data;
    
    led_breathe_display dut (
        .clk(clk),
        .rst_n(rst_n),
        .led_data(led_data)
    );
    
    // Clock generation: 50 MHz (20 ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20 ns period
    end
    
    initial begin
        // Initialize
        rst_n = 0;
        // Apply reset for a few cycles
        #100;
        rst_n = 1;
        
        // Wait for 1.5 seconds (1,500,000 cycles)
        #(1_500_000 * 20); // 1.5 seconds in ns
        $display("Simulation finished at time %t", $time);
        $finish;
    end
    
    // Print first few, last few, and key transitions
    reg [9:0] last_ms;
    integer print_count;
    initial begin
        last_ms = 0;
        print_count = 0;
    end
    
    always @(posedge clk) begin
        if (rst_n) begin
            // Print when ms_counter changes by at least 100 
            // to track progress
            if (dut.ms_counter >= 100 && dut.ms_counter <= 900 && 
                (dut.ms_counter - last_ms) >= 100) begin
                $display("Time %t: ms_counter = %0d, led_data = %0d", 
                         $time, dut.ms_counter, led_data);
                last_ms <= dut.ms_counter;
            end
            // Limit prints
            print_count <= print_count + 1;
            if (print_count > 20) $finish;
        end
    end
    
    // Monitor led_data changes
    reg [7:0] prev_led;
    initial prev_led = 0;
    always @(posedge clk) begin
        if (rst_n && (led_data !== prev_led)) begin
            $display("Time %t: led_data changed from %0d to %0d", 
                     $time, prev_led, led_data);
            prev_led <= led_data;
        end
    end
    
endmodule
