// Verilog code that resulted in empty output
// Saved at: 2026-01-14T19:27:53.734483
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

module peak_detector (
    input clk,
    input signed [11:0] lowpass_data,
    input signed [11:0] highpass_data,
    output signed [11:0] peak_low,
    output signed [11:0] peak_high,
    output valid
);

    // Parameters
    parameter INTERVAL_CYCLES = 333_000;  // 333,000 clock cycles
    localparam INTERVAL_COUNT_BITS = $clog2(INTERVAL_CYCLES); // enough bits
    
    reg [11:0] peak_low_reg;  // current peak register for lowpass
    reg [11:0] peak_high_reg;  // current peak register for highpass
    
    reg [INTERVAL_COUNT_BITS-1:0] counter;
    
    // Next peak values based on comparison with current stored peaks
    wire [11:0] next_peak_low;
    wire [11:0] next_peak_high;
    
    assign next_peak_low = (lowpass_data > peak_low_reg) ? lowpass_data : peak_low_reg;
    assign next_peak_high = (highpass_data > peak_high_reg) ? highpass_data : peak_high_reg;
    
    // Combinational reset if at start of interval (counter == 0)
    // We'll implement sequential update
    always @(posedge clk) begin
        if (counter == INTERVAL_CYCLES - 1) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end
    
    // Update peak registers
    always @(posedge clk) begin
        if (counter == 0) begin
            // Start of new interval: reset peak registers to minimum signed value (-2048)
            peak_low_reg <= 12'sh800; // -2048
            peak_high_reg <= 12'sh800;
        end else begin
            // Update peaks based on comparison
            peak_low_reg <= next_peak_low;
            peak_high_reg <= next_peak_high;
        end
    end
    
    // Latch output registers and valid signal at the end of interval
    reg [11:0] peak_low_out_reg, peak_high_out_reg;
    reg valid_reg;
    
    always @(posedge clk) begin
        if (counter == INTERVAL_CYCLES - 1) begin
            // Capture the peak values after considering the last sample
            // Note: we need to capture the updated peak for the last cycle.
            // The next_peak logic already includes the last inputs.
            peak_low_out_reg <= next_peak_low;
            peak_high_out_reg <= next_peak_high;
            valid_reg <= 1'b1;
        end else if (counter == 0) begin
            valid_reg <= 1'b0;
        end else begin
            valid_reg <= 1'b0;
        end
    end
    
    assign peak_low = peak_low_out_reg;
    assign peak_high = peak_high_out_reg;
    assign valid = valid_reg;
    
endmodule


// Testbench
module testbench;
    reg clk;
    reg signed [11:0] lowpass_data;
    reg signed [11:0] highpass_data;
    
    wire signed [11:0] peak_low;
    wire signed [11:0] peak_high;
    wire valid;
    
    peak_detector dut (
        .clk(clk),
        .lowpass_data(lowpass_data),
        .highpass_data(highpass_data),
        .peak_low(peak_low),
        .peak_high(peak_high),
        .valid(valid)
    );
    
    initial begin
        clk = 0;
        lowpass_data = 0;
        highpass_data = 0;
        
        // Generate clock (20 MHz, period 50 ns)
        forever #25 clk = ~clk;
    end
    
    initial begin
        // Initialize inputs
        lowpass_data = 0;
        highpass_data = 0;
        
        // Wait for initial values
        #100;
        
        // Test 1: Provide increasing lowpass data
        // Expect peak_low to be the maximum value seen during interval
        // Let's run for more than one interval to see behavior
        // We'll run for about 3 intervals (approx 1 ms simulation? Not enough.)
        // To simulate, we can run for a few cycles.
        // But we need to test with various values.
        // Let's do a simple test: provide a lowpass data that ramps up, then ramps down.
        // We'll also provide highpass data that spikes.
        
        // Wait for valid pulse to see previous interval? We'll just run a few cycles.
        // Let's run for 1000 cycles total.
        
        // First, reset with high values at first cycle? Not needed.
        // We'll start feeding data at time 100.
        
        // Provide lowpass data that increases from 0 to 1000 over 500 cycles,
        // then decreases to 0.
        // Provide highpass data that spikes to 2000 at cycle 300.
        
        #100;
        repeat (1000) begin
            @(posedge clk);
            // Generate simple patterns
            // lowpass_data = current counter value (simplified)
            // highpass_data = some function
            // We'll just assign random values for simplicity.
            lowpass_data = $random % 2048;
            highpass_data = $random % 2048;
        end
        
        #1000;
        $finish;
    end
    
    // Monitor outputs
    always @(posedge clk) begin
        if (valid) begin
            $display("At time %0t: valid=1, peak_low=%0d, peak_high=%0d", $time, peak_low, peak_high);
        end
    end
    
endmodule
