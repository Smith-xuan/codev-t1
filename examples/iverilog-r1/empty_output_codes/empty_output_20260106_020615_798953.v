// Verilog code that resulted in empty output
// Saved at: 2026-01-06T02:06:15.798983
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

module ClockDivider #(
    parameter DIVISOR = 8
)(
    input ClockIn,
    output ClockOut
);

reg [27:0] counter = 0;
reg clk_out_reg = 0;
wire clk_out;

// Handle special cases: DIVISOR = 0 or 1
assign ClockOut = (DIVISOR <= 1) ? ClockIn : clk_out;

// For normal operation
wire toggle1, toggle2, toggle;
reg [27:0] divisor_half;  // DIVISOR / 2 (floor division)
reg [27:0] toggle_point1; // divisor_half - 1

always @(*) begin
    divisor_half = DIVISOR / 2;  // integer division
    toggle_point1 = divisor_half - 1;
end

assign toggle1 = (counter == toggle_point1);
assign toggle2 = (counter == DIVISOR - 1);
assign toggle = toggle1 || toggle2;

// Counter logic
always @(posedge ClockIn) begin
    if (DIVISOR == 1) begin
        // Not used for counter
    end else begin
        if (counter == DIVISOR - 1) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end
end

// Output toggle flip-flop
always @(posedge ClockIn) begin
    if (DIVISOR <= 1) begin
        // Bypass, no toggling
    end else begin
        if (toggle) clk_out_reg <= ~clk_out_reg;
    end
end

assign clk_out = clk_out_reg;

endmodule

module testbench;
    reg clk;
    wire out8, out5;
    
    ClockDivider #(.DIVISOR(8)) dut8 (.ClockIn(clk), .ClockOut(out8));
    ClockDivider #(.DIVISOR(5)) dut5 (.ClockIn(clk), .ClockOut(out5));
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    integer cycle_count;
    integer high_count8, high_count5;
    reg prev_out8, prev_out5;
    
    initial begin
        cycle_count = 0;
        high_count8 = 0;
        high_count5 = 0;
        prev_out8 = 0;
        prev_out5 = 0;
        #500; // 50 cycles
        $display("\n=== Results after 50 input cycles ===");
        $display("DIVISOR=8: High cycles = %0d", high_count8);
        $display("DIVISOR=5: High cycles = %0d", high_count5);
        
        // Expected values
        // For DIVISOR=8: period 8 cycles, high for 4 cycles each period
        // In 50 cycles, there are 6 full periods (48 cycles) and 2 extra cycles.
        // Each full period high 4 cycles => 6*4 = 24. In first 2 extra cycles (0-1 indices), output high for counts 0,1 => 2 high cycles.
        // Total high = 24 + 2 = 26.
        $display("Expected high cycles for DIVISOR=8: 26");
        $display("DIVISOR=8 PASS: %s", (high_count8 == 26) ? "PASS" : "FAIL");
        
        // For DIVISOR=5: period 5 cycles, high for 2 cycles (floor(5/2)=2)
        // 50 cycles / 5 = 10 full periods => high 10*2 = 20.
        $display("Expected high cycles for DIVISOR=5: 20");
        $display("DIVISOR=5 PASS: %s", (high_count5 == 20) ? "PASS" : "FAIL");
        
        $finish;
    end
    
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;
        if (out8) high_count8 = high_count8 + 1;
        if (out5) high_count5 = high_count5 + 1;
        if (cycle_count == 50) $finish;
    end
    
endmodule
