// Verilog code that resulted in empty output
// Saved at: 2026-01-14T23:32:39.967543
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

module ALUOut (
    input clk,
    input rst_n,
    input [63:0] ALU_result_i,
    output reg [63:0] ALU_result_o
);

always @(posedge clk) begin
    if (rst_n) begin
        ALU_result_o <= 64'b0;
    end else begin
        ALU_result_o <= ALU_result_i;
    end
end

endmodule

module testbench;
    reg clk;
    reg rst_n;
    reg [63:0] ALU_result_i;
    wire [63:0] ALU_result_o;
    
    ALUOut dut (
        .clk(clk),
        .rst_n(rst_n),
        .ALU_result_i(ALU_result_i),
        .ALU_result_o(ALU_result_o)
    );
    
    initial begin
        clk = 0;
        rst_n = 0;
        ALU_result_i = 64'h0;
        
        // Test reset behavior
        #10 rst_n = 1;  // assert reset (active high)
        // At posedge clk, ALU_result_o should become 0
        #5 clk = 1; #5 clk = 0; // posedge at time 10+5? Actually we need to wait for posedge
        // Let's wait for a posedge
        @(posedge clk);
        #1; // small delay after posedge
        if (ALU_result_o !== 64'h0) begin
            $display("ERROR: Reset failed. ALU_result_o = %h", ALU_result_o);
            $finish;
        end else begin
            $display("Reset test passed.");
        end
        
        // Deassert reset and test normal storage
        rst_n = 0;
        ALU_result_i = 64'h123456789ABCDEF0;
        @(posedge clk);
        #1;
        if (ALU_result_o !== 64'h123456789ABCDEF0) begin
            $display("ERROR: Normal storage failed. ALU_result_o = %h", ALU_result_o);
            $finish;
        end else begin
            $display("Normal storage test passed.");
        end
        
        // Test changing input while reset deasserted
        ALU_result_i = 64'h0;
        @(posedge clk);
        #1;
        if (ALU_result_o !== 64'h0) begin
            $display("ERROR: Update failed. ALU_result_o = %h", ALU_result_o);
            $finish;
        end else begin
            $display("Update test passed.");
        end
        
        // Test reset while input non-zero
        ALU_result_i = 64'hDEADBEEFCAFEBABE;
        @(posedge clk); // store non-zero
        #1;
        // Now assert reset
        rst_n = 1;
        @(posedge clk);
        #1;
        if (ALU_result_o !== 64'h0) begin
            $display("ERROR: Reset while data present failed. ALU_result_o = %h", ALU_result_o);
            $finish;
        end else begin
            $display("Reset with data present test passed.");
        end
        
        // Test that output doesn't change on negedge clk
        ALU_result_i = 64'h1111111111111111;
        @(negedge clk);
        #1;
        // Should still be zero because no posedge yet
        if (ALU_result_o !== 64'h0) begin
            $display("ERROR: Output changed on negedge. ALU_result_o = %h", ALU_result_o);
            $finish;
        end
        
        // Wait for posedge to capture
        @(posedge clk);
        #1;
        if (ALU_result_o !== 64'h1111111111111111) begin
            $display("ERROR: Capture after negedge test failed.");
            $finish;
        end
        
        $display("All tests passed.");
        $finish;
    end
    
endmodule
