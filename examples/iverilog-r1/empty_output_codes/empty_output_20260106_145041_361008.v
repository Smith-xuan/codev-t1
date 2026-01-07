// Verilog code that resulted in empty output
// Saved at: 2026-01-06T14:50:41.361035
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

module debouncer #(
    parameter CLK_FREQ = 50_000_000  // 50 MHz
) (
    input button,
    input clk,
    input reset,
    output pressed,
    output held
);
    // Calculate number of clock cycles for 20 ms debounce interval
    localparam COUNT_MAX = (CLK_FREQ * 20) / 1000;
    // Ensure COUNT_MAX is at least 1
    localparam COUNT_MAX_USED = (COUNT_MAX < 1) ? 1 : COUNT_MAX;
    
    // Internal registers
    reg [31:0] counter;
    reg debounced;
    reg prev_debounced;
    
    // Continuous assignments
    assign held = debounced;
    assign pressed = debounced & ~prev_debounced;
    
    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            debounced <= 0;
            prev_debounced <= 0;
        end else begin
            // Counter logic
            if (counter == COUNT_MAX_USED - 1) begin
                counter <= 0;
                // Sample button
                debounced <= button;
            end else begin
                counter <= counter + 1;
            end
            
            // Edge detection
            prev_debounced <= debounced;
        end
    end
    
endmodule

// Testbench with reduced clock frequency for faster simulation
module testbench;
    reg button;
    reg clk;
    reg reset;
    wire pressed;
    wire held;
    
    // Instantiate DUT with CLK_FREQ = 1000 Hz (so COUNT_MAX = 20 cycles)
    // Clock period = 1/1000 = 1000 ns (1 us)
    // Actually CLK_FREQ = 1000 Hz => period = 1 ms = 1,000,000 ns? Wait, 1000 Hz = 1 ms period = 1,000,000 ns. Too long.
    // Better to use CLK_FREQ = 1_000_000 Hz (1 MHz) to get 20 us debounce interval.
    // Let's use CLK_FREQ = 1_000_000 Hz (1 MHz). Then COUNT_MAX = (1,000,000 * 20) / 1000 = 20,000 cycles.
    // Still large for simulation. Let's use CLK_FREQ = 10_000 Hz (10 kHz) => COUNT_MAX = 200 cycles.
    // Let's use CLK_FREQ = 1000 Hz => COUNT_MAX = 20 cycles. That's fine.
    // Clock period for 1000 Hz = 1 ms (1,000,000 ns). That's okay for simulation.
    // We'll generate clock with period 1,000,000 ns.
    
    // We'll override parameter in instantiation
    parameter SIM_CLK_FREQ = 1000;  // 1 kHz for simulation
    parameter SIM_COUNT_MAX = (SIM_CLK_FREQ * 20) / 1000;  // = 20
    
    // Generate clock with period = 1 / SIM_CLK_FREQ seconds
    // For 1 kHz, period = 1,000,000 ns
    // But we can use smaller period for faster simulation: use 1 MHz with reduced debounce time.
    // Let's change: use CLK_FREQ = 1_000_000 Hz but adjust debounce interval in localparam? Actually we can't.
    // Alternative: create a separate module with parameter for simulation.
    // Let's keep as is: use 1 kHz, but we can speed up by reducing the debounce interval for test? Not ideal.
    // Let's compute: we need COUNT_MAX = 20 cycles. We'll just simulate with 20 cycles of our own.
    // We'll manually set counter width to 5 bits and count to 19.
    // Instead, we can create a wrapper that overrides COUNT_MAX.
    // Actually, we can modify the DUT to have a parameter for COUNT_MAX directly.
    // Let's redesign: add parameter DEBOUNCE_CYCLES default to (CLK_FREQ * 20) / 1000.
    // That will make testbench simpler.
    
endmodule
