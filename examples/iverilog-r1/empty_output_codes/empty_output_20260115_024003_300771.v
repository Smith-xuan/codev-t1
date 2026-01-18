// Verilog code that resulted in empty output
// Saved at: 2026-01-15T02:40:03.300809
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
    
    parameter INITIAL_VALUE = 5000;
    
    reg [25:0] counter;
    reg clkOut_reg;
    
    assign clkOut = clkOut_reg;
    
    always @(posedge clock) begin
        if (reset) begin
            counter <= INITIAL_VALUE;
        end else if (counter == 0) begin
            clkOut_reg <= ~clkOut_reg;
            counter <= INITIAL_VALUE;
        end else begin
            counter <= counter - 1;
        end
    end
endmodule

module testbench;
    reg clock;
    reg reset;
    wire clkOut;
    
    // Instantiate with small value for testing
    clk_Div #(.INITIAL_VALUE(3)) dut (clock, reset, clkOut);
    
    initial begin
        clock = 0;
        reset = 1;
        
        // Apply reset for one clock cycle
        @(posedge clock);
        #1 reset = 0;
        
        $display("Starting simulation...");
        $display("Time\tCycle\tCounter\t\tclkOut");
        
        // Run for 20 clock cycles
        repeat (20) begin
            @(posedge clock);
            $display("%0t\t%0d\t%0d\t\t%b", $time, $time/10, dut.counter, clkOut);
        end
        
        $finish;
    end
endmodule
