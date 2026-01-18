// Verilog code that resulted in empty output
// Saved at: 2026-01-15T02:41:49.538328
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

module clk_Div (
    input clock,
    input reset,
    output clkOut
);
    
    // 26-bit counter initialized to 5000
    reg [25:0] counter;
    reg clkOut_reg;
    
    assign clkOut = clkOut_reg;
    
    always @(posedge clock) begin
        if (reset) begin
            // Reset counter to 5000, initialize clkOut to 0
            counter <= 26'd5000;
            clkOut_reg <= 1'b0;
        end else if (counter == 26'd1) begin
            // This is the last count before reaching 0
            // Toggle output and reload counter
            clkOut_reg <= ~clkOut_reg;
            counter <= 26'd5000;
        end else begin
            // Decrement counter normally
            counter <= counter - 26'd1;
        end
    end
    
endmodule

module testbench;
    reg clock;
    reg reset;
    wire clkOut;
    
    // Instance of the clock divider
    clk_Div dut (clock, reset, clkOut);
    
    integer cycle;
    reg last_clk;
    integer toggle_count;
    integer last_toggle_cycle;
    
    initial begin
        clock = 0;
        reset = 1;
        cycle = 0;
        last_clk = 0;
        toggle_count = 0;
        last_toggle_cycle = 0;
        
        // Apply reset for one clock cycle, then release
        @(posedge clock);
        #1 reset = 0;
        
        $display("Time\tCycle\tCounter\t\tclkOut\tAction");
        
        // Run for 20 clock cycles
        for (cycle = 1; cycle <= 20; cycle = cycle + 1) begin
            @(posedge clock);
            // Monitor values after the posedge
            $display("%0t\t%0d\t%0d\t\t%b", $time, cycle, dut.counter, clkOut);
            // Detect toggle
            if (cycle > 1) begin
                if (clkOut !== last_clk) begin
                    integer period;
                    period = cycle - last_toggle_cycle;
                    $display("  -> Toggle detected at cycle %0d (period since last toggle = %0d)", cycle, period);
                    toggle_count = toggle_count + 1;
                    last_toggle_cycle = cycle;
                    last_clk = clkOut;
                end else begin
                    last_clk = clkOut;
                end
            end else begin
                last_clk = clkOut;
            end
        end
        
        $finish;
    end
endmodule
