// Verilog code that resulted in empty output
// Saved at: 2026-01-07T04:57:42.255390
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

module Timer #(
    parameter WIDTH = 32,
    parameter TERMINAL_VALUE = 32'hFFFFFFFF
)(
    input clk,
    input start,
    output done
);

reg [WIDTH-1:0] count;

initial begin
    count = 0;
end

always @(posedge clk) begin
    if (start) begin
        if (count == TERMINAL_VALUE) begin
            count <= {WIDTH{1'b0}};
        end else begin
            count <= count + 1;
        end
    end
end

assign done = (start && (count == TERMINAL_VALUE));

endmodule

module testbench;
    reg clk;
    reg start;
    wire done;
    
    // Instantiate timer with small width for simulation
    Timer #(.WIDTH(4), .TERMINAL_VALUE(4'hF)) dut (.clk(clk), .start(start), .done(done));
    
    // Clock generation
    always #5 clk = ~clk;
    
    initial begin
        clk = 0;
        start = 0;
        
        // Test 1: start pulse, count to max (F), done pulse
        #10;
        start = 1;
        // Count from 0 to F (15) takes 15 cycles
        #150; // 15 cycles * 10ns period = 150ns
        // At this point, count should have wrapped to 0 after reaching F
        // Check that done pulsed at the cycle when count was F
        // We'll just monitor via VCD
        
        // Test 2: stop and resume
        #10;
        start = 0;
        #20;
        start = 1;
        #30;
        
        // Test 3: start inactive, count unchanged
        start = 0;
        #50;
        
        // Test 4: start stays high continuously, should count then wrap
        start = 1;
        #200;
        
        $finish;
    end
endmodule
