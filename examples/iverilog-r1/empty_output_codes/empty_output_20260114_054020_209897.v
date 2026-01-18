// Verilog code that resulted in empty output
// Saved at: 2026-01-14T05:40:20.209929
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

module b8counter(
    output reg [7:0] q,
    input clk,
    input rst,
    input [1:0] func,
    input [7:0] d
);
always @(posedge clk) begin
    if (rst) begin
        q <= 8'b0;
    end else begin
        case (func)
            2'b00: q <= d;
            2'b01: q <= d + 1;
            2'b11: q <= d - 1;
            default: q <= q; // hold when func=2'b10 or other undefined?
        endcase
    end
end
endmodule

module testbench;
    reg clk;
    reg rst;
    reg [1:0] func;
    reg [7:0] d;
    wire [7:0] q;
    
    b8counter uut (.q(q), .clk(clk), .rst(rst), .func(func), .d(d));
    
    initial begin
        // Initialize signals
        clk = 0;
        rst = 0;
        func = 2'b00;
        d = 8'h00;
        
        // Apply reset
        rst = 1;
        #10 clk = 1; #10 clk = 0; // posedge
        
        // Check reset: q should be 0
        if (q !== 8'h00) begin
            $display("ERROR: After reset, q = %h, expected 0", q);
            $finish;
        end
        
        // Test load operation: func=00, d=5 => q should become 5
        rst = 0;
        d = 8'h05;
        func = 2'b00;
        #10 clk = 1; #10 clk = 0;
        if (q !== 8'h05) begin
            $display("ERROR: Load: q = %h, expected 5", q);
            $finish;
        end
        
        // Test increment: func=01, d=5 => q should become d+1 = 6
        d = 8'h05;
        func = 2'b01;
        #10 clk = 1; #10 clk = 0;
        if (q !== 8'h06) begin
            $display("ERROR: Increment: q = %h, expected 6", q);
            $finish;
        end
        
        // Test decrement: func=11, d=10 => q should become d-1 = 9
        d = 8'h0A;
        func = 2'b11;
        #10 clk = 1; #10 clk = 0;
        if (q !== 8'h09) begin
            $display("ERROR: Decrement: q = %h, expected 9", q);
            $finish;
        end
        
        // Test hold: func=10, d arbitrary => q should hold previous value
        d = 8'hFF;
        func = 2'b10;
        #10 clk = 1; #10 clk = 0;
        if (q !== 8'h09) begin
            $display("ERROR: Hold: q = %h, expected 9", q);
            $finish;
        end
        
        // Test edge cases: d = 0, decrement should wrap? d-1 = 8'hFF (since 8-bit underflow)
        d = 8'h00;
        func = 2'b11;
        #10 clk = 1; #10 clk = 0;
        if (q !== 8'hFF) begin
            $display("ERROR: Decrement zero: q = %h, expected FF", q);
            $finish;
        end
        
        // Test d = 255, increment should wrap to 0
        d = 8'hFF;
        func = 2'b01;
        #10 clk = 1; #10 clk = 0;
        if (q !== 8'h00) begin
            $display("ERROR: Increment max: q = %h, expected 00", q);
            $finish;
        end
        
        // Test reset while other func
        rst = 1;
        #10 clk = 1; #10 clk = 0;
        if (q !== 8'h00) begin
            $display("ERROR: Reset after operations: q = %h, expected 0", q);
            $finish;
        end
        
        $display("All tests passed!");
        $finish;
    end
    
    // Clock generation (slow)
    initial begin
        #100 $finish;
    end
endmodule
