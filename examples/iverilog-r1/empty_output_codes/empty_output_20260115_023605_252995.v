// Verilog code that resulted in empty output
// Saved at: 2026-01-15T02:36:05.253023
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

// Use parameter for testing, but in real design it's fixed 5000
parameter INITIAL_VALUE = 3; // for testing, replace with 5000

reg [25:0] counter;
reg clkOut_reg;

assign clkOut = clkOut_reg;

always @(posedge clock) begin
    if (reset) begin
        counter <= INITIAL_VALUE;
        // clkOut_reg unchanged
    end else if (counter == 1) begin
        // On next cycle, counter would become 0, so toggle now and reload
        clkOut_reg <= ~clkOut_reg;
        counter <= INITIAL_VALUE;
    end else begin
        counter <= counter - 1;
    end
end

endmodule

// Testbench
module testbench;
    reg clock;
    reg reset;
    wire clkOut;
    
    // Instantiate with initial value 3 for testing
    clk_Div #(.INITIAL_VALUE(3)) dut (clock, reset, clkOut);
    
    initial begin
        clock = 0;
        reset = 1;
        
        // Wait for a posedge clock to capture reset
        @(posedge clock);
        #1 reset = 0;
        
        // Monitor changes
        $monitor("time=%0t clock=%b reset=%b counter=%0d clkOut=%b", $time, clock, reset, dut.counter, clkOut);
        
        // Run for enough cycles to see toggles
        repeat (30) begin
            @(posedge clock);
        end
        $finish;
    end
endmodule
