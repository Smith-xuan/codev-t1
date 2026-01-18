// Verilog code that resulted in empty output
// Saved at: 2026-01-14T05:46:11.881512
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

module detector (
    input clk,
    input rst,
    input sh_now,
    output flanco
);

reg sh_now_sync, sh_now_sync_prev;

// Sequential logic
always @(posedge clk) begin
    if (rst) begin
        sh_now_sync <= 1'b0;
        sh_now_sync_prev <= 1'b0;
    end else begin
        sh_now_sync <= sh_now;
        sh_now_sync_prev <= sh_now_sync;
    end
end

// Combinatorial output
assign flanco = sh_now_sync && !sh_now_sync_prev;

endmodule

module testbench;
    reg clk;
    reg rst;
    reg sh_now;
    wire flanco;
    
    detector dut (clk, rst, sh_now, flanco);
    
    initial begin
        clk = 0;
        rst = 1;
        sh_now = 0;
        #10 rst = 0;
        
        // Test case 1: rising edge at time 20 (just before clock edge at 30?)
        #10 sh_now = 1; // at time 20
        // Clock edge at time 30 (posedge)
        #20; // wait until time 40
        // Expect flanco high at time 30-40?
        
        // Keep sh_now high
        #30; // time 70
        
        // sh_now goes low at time 80, then high again at time 90
        #10 sh_now = 0; // time 80
        #10 sh_now = 1; // time 90
        // Clock edge at maybe 100? Let's just run for some cycles
        #50;
        
        $finish;
    end
    
    // Clock generation
    always #5 clk = ~clk;
    
endmodule
