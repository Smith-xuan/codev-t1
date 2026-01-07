// Verilog code that resulted in empty output
// Saved at: 2026-01-05T20:11:08.421814
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

module Debouncer250ms #(
    parameter CLK_FREQ = 100_000_000, // 100 MHz
    parameter DEBOUNCE_DELAY_MS = 250
) (
    input signal,
    input clk,
    output reg debounced
);

    // Calculate number of cycles for 250 ms
    localparam CYCLES_PER_MS = CLK_FREQ / 1000;
    localparam MAX_COUNT = DEBOUNCE_DELAY_MS * CYCLES_PER_MS; // 25,000,000
    
    // States
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        DETECTED = 2'b01,
        COUNTING = 2'b10
    } state_t;
    
    reg [25:0] counter;
    reg signal_prev;
    state_t state, next_state;
    
    // Edge detection
    wire signal_rising = signal && !signal_prev;
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (signal_rising) next_state = DETECTED;
            end
            DETECTED: begin
                next_state = COUNTING;
            end
            COUNTING: begin
                if (counter == MAX_COUNT - 1)
                    next_state = IDLE;
            end
        endcase
    end
    
    // Output logic
    always @(*) begin
        debounced = 1'b0;
        case (state)
            DETECTED, COUNTING: debounced = 1'b1;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk) begin
        signal_prev <= signal;
        counter <= 0;
        state <= next_state;
        
        case (next_state)
            IDLE: begin
                counter <= 0;
            end
            DETECTED: begin
                // start counting from 0 (already done)
            end
            COUNTING: begin
                if (counter < MAX_COUNT - 1)
                    counter <= counter + 1;
                else
                    counter <= 0; // optional, but we reset when leaving COUNTING
            end
        endcase
    end
    
endmodule


// Testbench with reduced delay for simulation
module testbench;
    reg clk;
    reg signal;
    wire debounced;
    
    // Instantiate with smaller delay for simulation (e.g., 10 cycles instead of 2.5 million)
    // We'll set CLK_FREQ=100MHz still, DEBOUNCE_DELAY_MS=0.01 ms? Not good.
    // Instead, we can directly override MAX_COUNT by using a different parameter.
    // Let's create a separate module with parameter override.
    // But we can define localparam differently for testbench.
    // We'll create a wrapper module that instantiates Debouncer250ms with a smaller delay.
    // However, we can't change localparam via hierarchy. So we'll modify Debouncer250ms to have a parameter for MAX_COUNT.
    // Let's do that: add parameter MAX_COUNT with default computed.
    // For simplicity, we'll create a separate module TestDebouncer with parameter.
    // Actually we can copy the module and adjust.
    
    // Instead, we'll simulate with a longer clock period to reduce number of cycles.
    // Let's keep clock period 10 ns, but set DEBOUNCE_DELAY_MS to a small value.
    // We'll compute: if we set DEBOUNCE_DELAY_MS = 0.0025 ms (i.e., 2.5 us), that's 2500 cycles at 100 MHz.
    // That's still many cycles. Let's set DEBOUNCE_DELAY_MS = 0.00001 ms (10 ns) -> 1 cycle.
    // That would test functionality but not the exact timing.
    // Better to create a test with a reduced MAX_COUNT parameter directly.
    
    // Let's create a modified module for testing:
    // We'll define a parameter TEST_MAX_COUNT and use it.
    
    // We'll modify Debouncer250ms to have a parameter MAX_COUNT with default computed.
    // Then instantiate with smaller MAX_COUNT.
    
    // Let's do that.
endmodule
