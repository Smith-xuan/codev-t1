// Verilog code that resulted in empty output
// Saved at: 2026-01-07T03:36:10.630417
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

module bin2bcd_4bit(
    input clk,
    input rst,
    input [3:0] binary,
    output reg [7:0] bcd
);

wire [3:0] tens, units;

assign tens = (binary >= 10) ? 4'd1 : 4'd0;
assign units = binary - (binary >= 10 ? 4'd10 : 4'd0);

always @(posedge clk) begin
    if (!rst) begin
        bcd <= 0;
    end else begin
        bcd <= {tens, units};
    end
end

endmodule

module testbench;
    reg clk;
    reg rst;
    reg [3:0] binary;
    wire [7:0] bcd;
    
    bin2bcd_4bit dut (.clk(clk), .rst(rst), .binary(binary), .bcd(bcd));
    
    // Clock generation: 30 cycles
    initial begin
        clk = 0;
        repeat (30) #5 clk = ~clk;
    end
    
    // Test sequence
    integer i;
    integer errors;
    initial begin
        errors = 0;
        // Initialize
        rst = 0;
        binary = 0;
        // Wait for first rising edge (with reset)
        @(posedge clk);
        #1; // wait for non-blocking assignment
        // Check reset value
        if (bcd !== 8'b0) begin
            $display("ERROR: Reset failed, bcd = %b", bcd);
            errors = errors + 1;
        end
        
        // Release reset and test each binary value
        rst = 1;
        // Test binary = 0
        binary = 0;
        @(posedge clk);
        #1;
        // Check bcd
        if (bcd[7:4] !== 1'b0) begin
            $display("ERROR at binary = %d: tens digit expected 0, got %d", binary, bcd[7:4]);
            errors = errors + 1;
        end
        if (bcd[3:0] !== 4'd0) begin
            $display("ERROR at binary = %d: units digit expected 0, got %d", binary, bcd[3:0]);
            errors = errors + 1;
        end
        
        // Test binary = 1 to 15
        for (i = 1; i < 16; i = i + 1) begin
            binary = i;
            @(posedge clk);
            #1;
            // Expected tens = (binary >= 10) ? 1 : 0
            // Expected units = binary - (binary >= 10 ? 10 : 0)
            if (bcd[7:4] !== (binary >= 10 ? 1 : 0)) begin
                $display("ERROR at binary = %d: tens digit expected %d, got %d", binary, binary >= 10 ? 1 : 0, bcd[7:4]);
                errors = errors + 1;
            end
            if (bcd[3:0] !== (binary - (binary >= 10 ? 10 : 0))) begin
                $display("ERROR at binary = %d: units digit expected %d, got %d", binary, binary - (binary >= 10 ? 10 : 0), bcd[3:0]);
                errors = errors + 1;
            end
        end
        
        // Test reset again while operating
        binary = 5;
        @(posedge clk);
        #1;
        // Now apply reset
        rst = 0;
        @(posedge clk);
        #1;
        if (bcd !== 8'b0) begin
            $display("ERROR: Reset after normal operation failed, bcd = %b", bcd);
            errors = errors + 1;
        end
        
        // Summary
        if (errors == 0) begin
            $display("All tests passed!");
        end else begin
            $display("Test failed with %d errors", errors);
        end
        $finish;
    end
endmodule
