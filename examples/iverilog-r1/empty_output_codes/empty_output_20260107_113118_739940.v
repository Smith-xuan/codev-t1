// Verilog code that resulted in empty output
// Saved at: 2026-01-07T11:31:18.739974
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

// Debounce_Single_Pulser module
module Debounce_Single_Pulser (
    input CLK,
    input D,
    output SP
);

    // Parameters for clock frequency and debounce time
    parameter CLK_FREQ = 50_000_000; // 50 MHz
    parameter DEBOUNCE_TIME_MS = 2;  // 2 ms debounce time
    
    // Calculate number of clock cycles for debounce period
    // N = (DEBOUNCE_TIME_MS * CLK_FREQ) / 1000
    // Ensure N is at least 1
    localparam N_CALC = (DEBOUNCE_TIME_MS * CLK_FREQ) / 1000;
    localparam N = (N_CALC == 0) ? 1 : N_CALC;
    
    // Optional: allow user to override N via parameter
    // parameter DEBOUNCE_CYCLES = N;
    
    // Registered synchronization flip-flops
    reg sync_d, sync_d_reg;
    always @(posedge CLK) begin
        sync_d <= D;
        sync_d_reg <= sync_d;
    end
    
    // Shift register for debouncing
    reg [N-1:0] shift_reg;
    reg debounced;
    reg prev_debounced;
    
    always @(posedge CLK) begin
        prev_debounced <= debounced;
        shift_reg <= {shift_reg[N-2:0], sync_d_reg};
        
        // Check if all bits of shift register are 1
        if (shift_reg == {N{1'b1}}) begin
            debounced <= 1'b1;
        end else begin
            debounced <= 1'b0;
        end
    end
    
    // Output pulse on rising edge of debounced signal
    assign SP = debounced & ~prev_debounced;
    
endmodule

// Testbench with reduced debounce for simulation
module testbench;
    reg CLK;
    reg D;
    wire SP;
    
    // Instantiate DUT with small debounce for simulation
    // Use 1 MHz clock (1 us period), debounce 10 cycles = 10 us
    Debounce_Single_Pulser #(
        .CLK_FREQ(1_000_000),   // 1 MHz
        .DEBOUNCE_TIME_MS(10)   // 10 ms -> actually 10 ms at 1 MHz is 10,000,000 ns, that's too long.
    ) dut (
        .CLK(CLK),
        .D(D),
        .SP(SP)
    );
    
    // Actually we need: debounce time = 10 us, clock period = 1 us => N = 10.
    // Let's compute: DEBOUNCE_TIME_MS = 10 * 0.001 = 0.01 ms? Wait.
    // To get 10 us debounce time with 1 MHz clock, we need DEBOUNCE_TIME_MS = 0.01? No.
    // Let's instead override N directly by using a global parameter override.
    // We'll modify the DUT to have an additional parameter DEBOUNCE_CYCLES.
    // For simplicity, we'll create a wrapper that passes N.
    
    // Let's do this differently: create a separate module for simulation with small N.
    
endmodule
