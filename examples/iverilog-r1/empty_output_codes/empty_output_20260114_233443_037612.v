// Verilog code that resulted in empty output
// Saved at: 2026-01-14T23:34:43.037640
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

module d_latch (
    output reg q,
    input d,
    input clk,
    input rst_n
);
always @(*) begin
    if (!rst_n) begin
        q = 1'b0;
    end else if (clk) begin
        q = d;
    end
end
endmodule

module dff_asyn (
    output reg q,
    input d,
    input clk,
    input rst_n
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q <= 1'b0;
    end else begin
        q <= d;
    end
end
endmodule

module dff_syn (
    output reg q,
    input d,
    input clk,
    input rst_n
);
always @(posedge clk) begin
    if (!rst_n) begin
        q <= 1'b0;
    end else begin
        q <= d;
    end
end
endmodule

module test_d_latch;
    reg d, clk, rst_n;
    wire q;
    
    d_latch dut (.q(q), .d(d), .clk(clk), .rst_n(rst_n));
    
    initial begin
        clk = 0;
        d = 0;
        rst_n = 1;
        #5;
        // Test reset
        $display("D Latch: Test reset");
        rst_n = 0;
        #10;
        $display("rst_n=%b -> q=%b (expect 0)", rst_n, q);
        if (q !== 0) $error("Reset failed");
        
        rst_n = 1;
        #5;
        // Test hold when clk low
        d = 1;
        #5;
        $display("clk=%b, d=%b -> q=%b (expect hold previous 0)", clk, d, q);
        if (q !== 0) $error("Hold failed");
        
        // Test transparent latch
        clk = 1;
        #5;
        $display("clk=1, d=1 -> q=%b (expect 1)", q);
        if (q !== 1) $error("Transparent failed");
        d = 0;
        #5;
        $display("clk=1, d=0 -> q=%b (expect 0)", q);
        if (q !== 0) $error("Transparent failed");
        
        // Test hold when clk low again
        clk = 0;
        d = 1;
        #5;
        $display("clk=0, d=1 -> q=%b (expect hold 0)", q);
        if (q !== 0) $error("Hold after clk low failed");
        
        $display("D Latch tests passed");
        $finish;
    end
    // Clock generator
    always #5 clk = ~clk;
endmodule

module test_dff_asyn;
    reg d, clk, rst_n;
    wire q;
    
    dff_asyn dut (.q(q), .d(d), .clk(clk), .rst_n(rst_n));
    
    initial begin
        clk = 0;
        d = 0;
        rst_n = 1;
        #5;
        $display("Async DFF: Initial state");
        $display("q=%b (should be x)", q);
        
        // Test async reset
        $display("\nAsync DFF: Apply reset");
        rst_n = 0;
        #10;
        $display("rst_n=%b -> q=%b (expect 0)", rst_n, q);
        if (q !== 0) $error("Async reset failed");
        
        // Release reset, no clock edge yet
        rst_n = 1;
        d = 1;
        #10;
        $display("rst_n=%b, d=1, clk=%b -> q=%b (expect 0)", rst_n, clk, q);
        if (q !== 0) $error("No clock edge failed");
        
        // Apply posedge clk
        clk = 1;
        #5; // posedge at time 15?
        $display("clk=1 -> q=%b (expect 1)", q);
        if (q !== 1) $error("Capture failed");
        
        // Test async reset during operation
        #5;
        rst_n = 0;
        #5;
        $display("rst_n=0 -> q=%b (expect 0 immediately)", q);
        if (q !== 0) $error("Async reset during operation failed");
        
        $display("Async DFF tests passed");
        $finish;
    end
    // Clock generator
    always #5 clk = ~clk;
endmodule

module test_dff_syn;
    reg d, clk, rst_n;
    wire q;
    
    dff_syn dut (.q(q), .d(d), .clk(clk), .rst_n(rst_n));
    
    initial begin
        clk = 0;
        d = 0;
        rst_n = 1;
        #5;
        $display("Sync DFF: Initial state");
        $display("q=%b (should be x)", q);
        
        // Test synchronous reset
        $display("\nSync DFF: Apply reset");
        rst_n = 0;
        #10;
        $display("rst_n=%b -> q=%b (expect x, no clock edge)", rst_n, q);
        // q may be x because no posedge clk yet.
        
        // Apply posedge clk with reset still active
        clk = 1;
        #5;
        $display("posedge clk with rst_n=0 -> q=%b (expect 0)", q);
        if (q !== 0) $error("Sync reset on posedge failed");
        
        // Release reset, data capture
        rst_n = 1;
        d = 1;
        #5;
        $display("clk=%b -> q=%b (expect 1)", clk, q);
        if (q !== 1) $error("Capture after reset release failed");
        
        // Test synchronous reset with data change before posedge
        d = 0;
        #5;
        $display("d changed to 0 before posedge -> q=%b (still 1)", q);
        clk = 0;
        #5;
        clk = 1;
        #5;
        $display("posedge with d=0 -> q=%b (expect 0)", q);
        if (q !== 0) $error("Sync capture with new data failed");
        
        $display("Sync DFF tests passed");
        $finish;
    end
    // Clock generator
    always #5 clk = ~clk;
endmodule

module testbench;
    // Instantiate all three tests
endmodule
