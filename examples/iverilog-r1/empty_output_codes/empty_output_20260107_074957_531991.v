// Verilog code that resulted in empty output
// Saved at: 2026-01-07T07:49:57.532021
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

module Program_Counter (
    input clk_i,
    input rst_n,
    input [31:0] pc_in_i,
    output reg [31:0] pc_out_o
);
always @(posedge clk_i) begin
    if (!rst_n) begin
        pc_out_o <= 32'b0;
    end else begin
        pc_out_o <= pc_in_i;
    end
end
endmodule

module testbench;
reg clk_i;
reg rst_n;
reg [31:0] pc_in_i;
wire [31:0] pc_out_o;

Program_Counter dut (
    .clk_i(clk_i),
    .rst_n(rst_n),
    .pc_in_i(pc_in_i),
    .pc_out_o(pc_out_o)
);

// Clock generation with timeout
initial begin
    clk_i = 0;
    forever begin
        #5 clk_i = ~clk_i;
        #5 if ($time > 100) $finish;
    end
end

initial begin
    // Test 1: Reset
    rst_n = 1'b0;
    pc_in_i = 32'h0;
    @(posedge clk_i);
    // Check after a small delay
    #1;
    if (pc_out_o !== 32'h0) begin
        $error("Reset failed: expected 0, got %h", pc_out_o);
        $finish;
    end
    
    // Test 2: Load value after reset
    rst_n = 1'b1;
    pc_in_i = 32'h12345678;
    @(posedge clk_i);
    #1;
    if (pc_out_o !== 32'h12345678) begin
        $error("Load failed: expected 12345678, got %h", pc_out_o);
        $finish;
    end
    
    // Test 3: Load max value
    pc_in_i = 32'hFFFFFFFF;
    @(posedge clk_i);
    #1;
    if (pc_out_o !== 32'hFFFFFFFF) begin
        $error("Load failed: expected FFFFFFFF, got %h", pc_out_o);
        $finish;
    end
    
    // Test 4: Load zero
    pc_in_i = 32'h0;
    @(posedge clk_i);
    #1;
    if (pc_out_o !== 32'h0) begin
        $error("Load failed: expected 0, got %h", pc_out_o);
        $finish;
    end
    
    // Test 5: Reset while loading
    pc_in_i = 32'hDEADBEEF;
    @(posedge clk_i);
    #1;
    if (pc_out_o !== 32'hDEADBEEF) begin
        $error("Load failed: expected DEADBEEF, got %h", pc_out_o);
        $finish;
    end
    rst_n = 1'b0;
    @(posedge clk_i);
    #1;
    if (pc_out_o !== 32'h0) begin
        $error("Reset after load failed: expected 0, got %h", pc_out_o);
        $finish;
    end
    
    // Test 6: Load after reset
    rst_n = 1'b1;
    pc_in_i = 32'hA5A5A5A5;
    @(posedge clk_i);
    #1;
    if (pc_out_o !== 32'hA5A5A5A5) begin
        $error("Load after reset failed: expected A5A5A5A5, got %h", pc_out_o);
        $finish;
    end
    
    $display("All tests passed.");
    $finish;
end
endmodule
