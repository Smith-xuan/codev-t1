// Verilog code that resulted in empty output
// Saved at: 2026-01-14T23:10:36.605378
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

module top_module (
    input clk,
    input reset,
    output shift_ena
);

reg [2:0] counter;

always @(posedge clk) begin
    if (reset) begin
        counter <= 3'd0;
    end else begin
        if (counter < 4) begin
            counter <= counter + 1;
        end
    end
end

assign shift_ena = (counter < 4);

endmodule

module testbench;
    reg clk;
    reg reset;
    wire shift_ena;
    
    top_module dut (.clk(clk), .reset(reset), .shift_ena(shift_ena));
    
    reg [31:0] cycle;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    initial begin
        clk = 0;
        reset = 1;
        cycle = 0;
        
        // Release reset after 2 cycles
        #20 reset = 0;
        
        // Run for 15 cycles
        #140 $finish;
    end
    
    always @(posedge clk) begin
        $display("Cycle %0d: reset=%0d, shift_ena=%0d, counter=%0d", cycle, reset, shift_ena, dut.counter);
    end
endmodule
