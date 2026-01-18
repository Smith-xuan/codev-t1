// Verilog code that resulted in empty output
// Saved at: 2026-01-14T01:38:27.267419
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

module pfpu_if (
    input sys_clk,
    input alu_rst,
    input [31:0] a,
    input [31:0] b,
    input ifb,
    input valid_i,
    output reg [31:0] r,
    output reg valid_o
);

always @(posedge sys_clk) begin
    if (alu_rst) begin
        valid_o <= 1'b0;
        // Optionally reset r to 0; spec doesn't say, but we'll do it for cleanliness
        r <= 32'b0;
    end else begin
        valid_o <= valid_i;
        // select a when ifb=1, b when ifb=0
        r <= ifb ? a : b;
    end
end

endmodule

module testbench;
    reg sys_clk;
    reg alu_rst;
    reg [31:0] a;
    reg [31:0] b;
    reg ifb;
    reg valid_i;
    wire [31:0] r;
    wire valid_o;

    pfpu_if dut (
        .sys_clk(sys_clk),
        .alu_rst(alu_rst),
        .a(a),
        .b(b),
        .ifb(ifb),
        .valid_i(valid_i),
        .r(r),
        .valid_o(valid_o)
    );

    initial begin
        sys_clk = 0;
        // Initialize signals
        alu_rst = 1'b0;
        a = 32'h0000_0000;
        b = 32'h0000_0000;
        ifb = 1'b0;
        valid_i = 1'b0;

        // Apply reset
        alu_rst = 1'b1;
        @(posedge sys_clk);
        // Check reset behavior: valid_o should be 0, r should be 0 (if we reset)
        #1; // wait a bit after clock edge
        if (valid_o !== 1'b0) begin
            $display("ERROR: valid_o not 0 after reset");
            $finish;
        end
        if (r !== 32'h0) begin
            $display("ERROR: r not 0 after reset, got %h", r);
            $finish;
        end

        // Release reset and test selection
        alu_rst = 1'b0;
        a = 32'h1234_5678;
        b = 32'h8765_4321;
        ifb = 1'b1; // select a
        valid_i = 1'b1;
        @(posedge sys_clk);
        #1;
        if (valid_o !== 1'b1) begin
            $display("ERROR: valid_o not 1 after reset release");
            $finish;
        end
        if (r !== a) begin
            $display("ERROR: r not equal to a (a=%h, r=%h)", a, r);
            $finish;
        end

        // Change to select b
        ifb = 1'b0;
        valid_i = 1'b0;
        @(posedge sys_clk);
        #1;
        if (valid_o !== 1'b0) begin
            $display("ERROR: valid_o not 0 for invalid_i");
            $finish;
        end
        if (r !== b) begin
            $display("ERROR: r not equal to b (b=%h, r=%h)", b, r);
            $finish;
        end

        // Test with different values
        a = 32'hAAAA_AAAA;
        b = 32'h5555_5555;
        ifb = 1'b1;
        valid_i = 1'b1;
        @(posedge sys_clk);
        #1;
        if (r !== a) begin
            $display("ERROR: r mismatch for a");
            $finish;
        end
        if (valid_o !== 1'b1) begin
            $display("ERROR: valid_o mismatch");
            $finish;
        end

        // Edge case: ifb changes while a and b change
        a = 32'hDEAD_BEEF;
        b = 32'hCAFEBABE;
        ifb = 1'b0;
        valid_i = 1'b1;
        @(posedge sys_clk);
        #1;
        if (r !== b) begin
            $display("ERROR: r mismatch for b");
            $finish;
        end

        // Test reset while valid_i is high
        a = 32'h1111_1111;
        b = 32'h2222_2222;
        ifb = 1'b1;
        valid_i = 1'b1;
        @(posedge sys_clk);
        #1;
        // Now assert reset
        alu_rst = 1'b1;
        @(posedge sys_clk);
        #1;
        if (valid_o !== 1'b0) begin
            $display("ERROR: valid_o not 0 after reset asserted");
            $finish;
        end
        if (r !== 32'h0) begin
            $display("ERROR: r not reset to 0, r=%h", r);
            $finish;
        end

        // Release reset and ensure normal operation resumes
        alu_rst = 1'b0;
        a = 32'h3333_3333;
        b = 32'h4444_4444;
        ifb = 1'b0;
        valid_i = 1'b1;
        @(posedge sys_clk);
        #1;
        if (valid_o !== 1'b1) begin
            $display("ERROR: valid_o not 1 after reset release");
            $finish;
        end
        if (r !== b) begin
            $display("ERROR: r not equal to b after reset release");
            $finish;
        end

        $display("All tests passed");
        $finish;
    end

endmodule
