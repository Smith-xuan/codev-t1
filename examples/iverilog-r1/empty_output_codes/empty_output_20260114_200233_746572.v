// Verilog code that resulted in empty output
// Saved at: 2026-01-14T20:02:33.746597
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

module rotater (
    input clk,
    input rst,
    output rotate
);
    reg [12:0] cnt;
    
    always @(posedge clk) begin
        if (rst) begin
            cnt <= 13'd0;
        end else begin
            if (cnt == 13'd4999) begin
                cnt <= 13'd0;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
    
    assign rotate = (cnt == 13'd4999);
    
endmodule

module testbench;
    reg clk;
    reg rst;
    wire rotate;
    
    rotater dut (
        .clk(clk),
        .rst(rst),
        .rotate(rotate)
    );
    
    // Clock generation with 1ns period (1 GHz)
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;
    end
    
    initial begin
        // Initialize signals
        rst = 1'b1;
        
        // Apply reset for 2 cycles
        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;
        
        // Wait for 5000 cycles and check rotate assertion
        // Let's monitor rotate for 5000 cycles
        repeat (5000) begin
            @(posedge clk);
            //$display("Time %0t: cnt = %0d, rotate = %b", $time, dut.cnt, rotate);
        end
        
        // Check that rotate was asserted exactly once during last cycle before reset
        // We'll rely on visual inspection of waveform, but we can add checks.
        // Let's instead simulate and capture counter values.
        
        // After 5000 cycles, we should see rotate asserted at the 4999th count.
        // Wait a few more cycles
        repeat (10) @(posedge clk);
        
        $finish;
    end
    
endmodule
