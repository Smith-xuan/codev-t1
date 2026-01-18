// Verilog code that resulted in empty output
// Saved at: 2026-01-15T10:02:24.122686
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

module key_debounce #(
    parameter CLK_FREQ = 50_000_000 // 50 MHz
) (
    input sys_clk,
    input sys_rst_n,
    input key,
    output reg keyvalue,
    output reg keyflag
);
    // Calculate number of clock cycles corresponding to 20 ms
    // DEBOUNCE_CYCLES = CLK_FREQ * 0.02 = CLK_FREQ * 20 / 1000 = CLK_FREQ / 50
    localparam DEBOUNCE_CYCLES = (CLK_FREQ * 20) / 1000;
    
    // Counter width sufficient to hold DEBOUNCE_CYCLES-1
    localparam COUNTER_WIDTH = $clog2(DEBOUNCE_CYCLES + 1);
    reg [COUNTER_WIDTH-1:0] count;
    
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            keyvalue <= 1'b0;
            keyflag <= 1'b0;
            count <= 0;
        end else begin
            // Default keyflag to 0
            keyflag <= 1'b0;
            
            // Default count to 0 if key matches current keyvalue
            if (key == keyvalue) begin
                count <= 0;
            end else begin
                // Key differs: increment counter if not at max
                if (count == DEBOUNCE_CYCLES - 1) begin
                    // Debounce period elapsed
                    keyvalue <= key;
                    keyflag <= 1'b1;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
        end
    end
endmodule

module testbench;
    reg sys_clk = 0;
    reg sys_rst_n = 0;
    reg key = 0;
    wire keyvalue;
    wire keyflag;
    
    // Instantiate DUT with a small debounce cycles for quick simulation
    key_debounce #(
        .CLK_FREQ(100_000_000)  // 100 MHz, but we will reduce DEBOUNCE_CYCLES
    ) dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .key(key),
        .keyvalue(keyvalue),
        .keyflag(keyflag)
    );
    
    // We can manually override DEBOUNCE_CYCLES by using a smaller parameter.
    // However the DUT uses localparam based on CLK_FREQ.
    // Instead, we can create a wrapper with a different parameter.
    // Let's instead set CLK_FREQ to a very low value to reduce cycles.
    // For simulation, let's compute DEBOUNCE_CYCLES = 10.
    // We'll modify the DUT in testbench by using a different module with parameter.
    // Let's create a separate module that inherits key_debounce and passes a parameter.
    
    // For simplicity, we will directly instantiate key_debounce with CLK_FREQ = 1000
    // so DEBOUNCE_CYCLES = (1000 * 20)/1000 = 20 cycles? Wait formula is (CLK_FREQ * 20)/1000.
    // So for CLK_FREQ = 1000, DEBOUNCE_CYCLES = 20 cycles.
    // That's fine.
    
    // Let's change instantiation: 
    // key_debounce #(.CLK_FREQ(1000)) dut (...);
    // However the DUT's localparam uses (CLK_FREQ * 20) / 1000.
    // That's 20 cycles.
    
    // Let's use CLK_FREQ = 50000 to get 1000 cycles? Actually (50000*20)/1000 = 1000 cycles.
    // We'll just keep CLK_FREQ=100000000 as default but we can override.
    // Instead, we'll directly compute DEBOUNCE_CYCLES in the testbench and pass as parameter.
    // But the module only has one parameter CLK_FREQ.
    
    // Let's just use a small CLK_FREQ for simulation.
    // Let's change: 
    // key_debounce #(.CLK_FREQ(1000)) dut (...);
    // Then DEBOUNCE_CYCLES = (1000 * 20) / 1000 = 20.
    // That's okay.
    
    // Let's adjust the code: replace the DUT instantiation.
    
    // We'll do a fresh simulation with proper parameter.
    
    // Let's restart the simulation with corrected code.
    
endmodule
