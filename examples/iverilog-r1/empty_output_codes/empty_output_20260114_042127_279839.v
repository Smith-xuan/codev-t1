// Verilog code that resulted in empty output
// Saved at: 2026-01-14T04:21:27.279868
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

module divide_signal(
    input clk,
    input reset,
    output clk_div2,
    output clk_div4,
    output clk_div8
);
    reg [2:0] count;
    
    always @(posedge clk) begin
        if (reset) begin
            count <= 3'b0;
        end else begin
            count <= count + 1;
        end
    end
    
    assign clk_div2 = count[0];
    assign clk_div4 = count[1];
    assign clk_div8 = count[2];
endmodule

module testbench;
    reg clk;
    reg reset;
    wire clk_div2, clk_div4, clk_div8;
    
    divide_signal dut (
        .clk(clk),
        .reset(reset),
        .clk_div2(clk_div2),
        .clk_div4(clk_div4),
        .clk_div8(clk_div8)
    );
    
    initial begin
        clk = 0;
        reset = 1;
        
        // Apply reset
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        
        // Monitor outputs
        $display("Time\tclk\treset\tdiv2\tdiv4\tdiv8");
        $monitor("%0d\t%b\t%b\t%b\t%b\t%b", $time, clk, reset, clk_div2, clk_div4, clk_div8);
        
        // Run for 20 clock cycles
        repeat (20) @(posedge clk);
        $finish;
    end
endmodule
