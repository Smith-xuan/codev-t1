// Verilog code that resulted in empty output
// Saved at: 2026-01-14T03:55:15.475444
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

module linear (
    input [3:0] u,
    input clk,
    output reg [6:0] c
);

wire [2:0] xor_bits;

assign xor_bits[2] = u[1] ^ u[2] ^ u[3];
assign xor_bits[1] = u[0] ^ u[1] ^ u[2];
assign xor_bits[0] = u[0] ^ u[2] ^ u[3];

always @(posedge clk) begin
    c <= {u[3:0], xor_bits};
end

endmodule

module testbench;
    reg [3:0] u;
    reg clk;
    wire [6:0] c;
    
    linear dut ( .u(u), .clk(clk), .c(c) );
    
    initial begin
        clk = 0;
        u = 4'b0000;
        #10;
        @(posedge clk);
        #1;
        $display("Test 1: u=%b, c=%b", u, c);
        if (c !== 7'b0000000) $error("Test 1 failed");
        
        u = 4'b1111;
        #10;
        @(posedge clk);
        #1;
        $display("Test 2: u=%b, c=%b", u, c);
        if (c !== 7'b1111111) $error("Test 2 failed");
        
        u = 4'b1010;
        #10;
        @(posedge clk);
        #1;
        $display("Test 3: u=%b, c=%b", u, c);
        if (c !== 7'b1010011) $error("Test 3 failed");
        
        u = 4'b0101;
        #10;
        @(posedge clk);
        #1;
        $display("Test 4: u=%b, c=%b", u, c);
        if (c !== 7'b0101100) $error("Test 4 failed");
        
        u = 4'b0001;
        #10;
        @(posedge clk);
        #1;
        $display("Test 5: u=%b, c=%b", u, c);
        if (c !== 7'b0001011) $error("Test 5 failed");
        
        $display("All tests passed");
        $finish;
    end
    
endmodule
