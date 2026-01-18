// Verilog code that resulted in empty output
// Saved at: 2026-01-14T01:02:58.948191
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

module Debounce_Single_Pulser #(
    parameter CLK_FREQ = 100_000_000,   // default 100 MHz
    parameter DESIRED_DELAY_MS = 2
) (
    input CLK,
    input D,
    output SP
);

    // Compute number of clock cycles needed for desired delay
    localparam DEBOUNCE_CYCLES = (CLK_FREQ * DESIRED_DELAY_MS) / 1000;
    localparam COUNTER_WIDTH = $clog2(DEBOUNCE_CYCLES > 0 ? DEBOUNCE_CYCLES : 1);

    reg [COUNTER_WIDTH-1:0] counter;
    reg [1:0] sync_reg;
    reg flag_r;
    reg flag_r_delayed;

    wire sync;
    assign sync = sync_reg[1];

    always @(posedge CLK) begin
        // Synchronizer chain
        sync_reg <= {sync_reg[0], D};

        // Counter logic
        if (sync_reg[1]) begin
            // Input is high, increment counter up to max
            if (counter == DEBOUNCE_CYCLES - 1) begin
                // hold at max value
                counter <= counter;
            end else begin
                counter <= counter + 1;
            end
        end else begin
            counter <= 0;
        end

        // Flag logic
        if (!sync_reg[1]) begin
            // Input low, clear flag
            flag_r <= 1'b0;
        end else begin
            // Input high, set flag when counter reaches threshold and flag is low
            if (counter == DEBOUNCE_CYCLES - 1 && !flag_r) begin
                flag_r <= 1'b1;
            end
        end
    end

    // Delayed version for edge detection
    always @(posedge CLK) begin
        flag_r_delayed <= flag_r;
    end

    // Output is rising edge of flag_r
    assign SP = flag_r && !flag_r_delayed;

endmodule

module testbench;
    reg CLK;
    reg D;
    wire SP;

    // Instantiate DUT with a faster simulation clock to reduce simulation time.
    // For simulation, we can use a lower frequency to reduce cycles.
    // Let's set CLK_FREQ to 1_000 (1 kHz) to make simulation manageable.
    // Then DEBOUNCE_CYCLES = (1_000 * 2) / 1000 = 2 cycles.
    // That's easier to simulate.
    // Override parameters using defparam.
    // Actually we can use parameter override in instance.

    Debounce_Single_Pulser #(
        .CLK_FREQ(1_000),          // 1 kHz clock for simulation
        .DESIRED_DELAY_MS(2)
    ) dut (
        .CLK(CLK),
        .D(D),
        .SP(SP)
    );

    // Clock generation: 1 kHz => period = 1 ms = 1_000_000 ns? Wait: 1 kHz = 1000 cycles per second = period = 1 ms = 1,000,000 ns? Actually 1 ms = 1,000,000 ns? No: 1 second = 1,000,000,000 ns. So 1 ms = 1,000,000 ns. That's 1,000,000 ns period, half period = 500,000 ns. That's huge simulation time. Let's use 1 MHz (1 us period) to keep simulation reasonable.
    // Let's change CLK_FREQ to 1_000_000 (1 MHz) => period = 1 us.
    // DEBOUNCE_CYCLES = (1,000,000 * 2) / 1000 = 2000 cycles.
    // That's simulation of 2000 cycles okay.

    // Let's adjust: we'll keep CLK_FREQ as 1_000_000.
    // Actually we can set CLK_FREQ to 1_000,000 (1 MHz). Then clock period = 1 us.
    // Generate clock with period 1 us.
    // Let's recalc parameters.

    // Use a faster clock: 1 MHz = 1 us period.
    // So we'll generate clock with period 1000 ns (1 us). Actually 1 us = 1,000,000 ns? Wait: 1 us = 1000 ns? No: 1 us = 1 microsecond = 1000 nanoseconds.
    // So clock period = 1000 ns.

    // Let's modify: set CLK_FREQ to 1_000_000 (1 MHz). That's 1,000,000 cycles per second.
    // Then DEBOUNCE_CYCLES = (1,000,000 * 2) / 1000 = 2000 cycles.
    // Each clock cycle at 1 MHz is 1 us.
    // Simulating 2000 cycles is fine.

    // Let's rewrite testbench with proper timing.
    // We'll keep the instance as is but override parameters.
    // I'll re-instantiate with correct values.

    // Actually we can just compute DEBOUNCE_CYCLES as 2000.
    // I'll manually compute and hardcode.

endmodule
