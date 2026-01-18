// Verilog code that resulted in empty output
// Saved at: 2026-01-14T06:41:39.114051
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

module timer(
    input clock,
    input reset,
    output reg [3:0] timer
);
    // internal 20-bit counter
    reg [19:0] count;
    // maximum count for 1 second at 1 MHz
    // Could be parameterized for testing
    parameter COUNTER_MAX = 20'd999999;

    always @(posedge clock) begin
        if (reset) begin
            count <= 20'd0;
            timer <= 4'd0;
        end else begin
            if (count == COUNTER_MAX) begin
                count <= 20'd0;
                // increment timer with wrap-around (modulo 16)
                timer <= timer + 1'b1;
            end else begin
                count <= count + 1'b1;
            end
        end
    end

endmodule

// Testbench with small COUNTER_MAX
module testbench;
    reg clock;
    reg reset;
    wire [3:0] timer;
    
    // Override parameter to a small value for testing
    localparam TEST_MAX = 20'd5;  // increment every 6 cycles
    
    // Instantiate timer with overridden parameter using defparam
    // Since the module header doesn't have a parameter, we need to use 
    // a wrapper. Instead, let's modify the timer module to have a parameter
    // but keep default value as per spec. We'll do that.
    
    // Here we will create a wrapper module that instantiates the timer
    // with a different COUNTER_MAX. But we can also use `defparam` if we
    // define the parameter inside the module.
    
    // Let's create a new module timer_test that inherits from timer with parameter.
    // Actually we can define a module with parameter and use it.
    
    // Simpler: we will define a new module 'timer_test' that includes the
    // same logic but with a parameter. Then instantiate that.
    
    // However, due to time, we can just use defparam on an instance if the 
    // parameter is defined in the module. Let's define the parameter in the timer
    // module header.
    
    // Let's define the timer module again with a parameter.
    
endmodule
