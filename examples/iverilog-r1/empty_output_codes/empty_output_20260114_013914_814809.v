// Verilog code that resulted in empty output
// Saved at: 2026-01-14T01:39:14.814849
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
        // Reset only affects valid_o
        valid_o <= 1'b0;
        // r is not updated during reset, retains its previous value
    end else begin
        // Normal operation: propagate valid_i and select data
        valid_o <= valid_i;
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
        // Initialize signals (simulate unknown states)
        alu_rst = 1'b0;
        a = 32'h0000_0000;
        b = 32'h0000_0000;
        ifb = 1'b0;
        valid_i = 1'b0;

        // Start with unknown state
        @(posedge sys_clk);
        // After first clock edge, r and valid_o are still X because no data changed? Wait, we have no data?
        // Actually, at first posedge, a,b,ifb,valid_i are all zeros, so r should become a (0) and valid_o becomes valid_i (0).
        // But our initial values are zero, so after first clock edge, r should be 0 and valid_o should be 0.
        // However, registers are not initialized, so they could be X. But they are updated with zeros.
        // Let's wait a bit then check after some clock cycles.
        
        // Apply reset to clear valid_o
        alu_rst = 1'b1;
        @(posedge sys_clk);
        #1;
        if (valid_o !== 1'b0) begin
            $display("ERROR: valid_o not 0 after reset");
            $finish;
        end
        // Check that r does NOT change on reset (i.e., still previous value)
        // Previous value was unknown (X). But we can't compare X. Instead, we can set a known value before reset.
        // Let's set known values before reset.
        // We'll restructure test to be more robust.

        // Let's restart test with known state before reset.
        // We'll reset everything to known values before applying reset.
        // Actually, we can't set internal register values directly. We'll need to set them before reset by first operating normally.
        // So we'll first get a known r value, then assert reset and ensure r stays same.
        // Let's do that.
        
        // Phase 1: get known r value
        alu_rst = 1'b0;
        a = 32'h1234_5678;
        b = 32'h8765_4321;
        ifb = 1'b1; // select a
        valid_i = 1'b1;
        @(posedge sys_clk);
        #1;
        if (r !== a) begin
            $display("ERROR: r not equal to a in phase1, got %h", r);
            $finish;
        end
        if (valid_o !== 1'b1) begin
            $display("ERROR: valid_o not 1 in phase1");
            $finish;
        end
        // Now r holds a = 0x12345678
        
        // Phase 2: assert reset, r should not change
        alu_rst = 1'b1;
        // Change a and b to different values to see if r changes
        a = 32'hAAAA_AAAA;
        b = 32'h5555_5555;
        ifb = 1'b1; // still select a (new a)
        valid_i = 1'b0; // valid_i low
        @(posedge sys_clk);
        #1;
        // After reset, valid_o should be 0 (since alu_rst=1)
        if (valid_o !== 1'b0) begin
            $display("ERROR: valid_o not 0 after reset");
            $finish;
        end
        // r should still be previous value (0x12345678), not new a (0xAAAAAAAA)
        if (r !== 32'h1234_5678) begin
            $display("ERROR: r changed on reset, expected 12345678, got %h", r);
            $finish;
        end
        // Select b while reset active
        ifb = 1'b0;
        @(posedge sys_clk);
        #1;
        // r should still not change
        if (r !== 32'h1234_5678) begin
            $display("ERROR: r changed when selecting b during reset");
            $finish;
        end
        
        // Phase 3: deassert reset, r should update with new selection
        alu_rst = 1'b0;
        // Keep same a and b
        ifb = 1'b0; // select b
        valid_i = 1'b1;
        @(posedge sys_clk);
        #1;
        if (r !== b) begin
            $display("ERROR: r not equal to b after reset release");
            $finish;
        end
        if (valid_o !== 1'b1) begin
            $display("ERROR: valid_o not 1 after reset release");
            $finish;
        end
        
        // Additional test: reset while valid_i high
        a = 32'h1111_1111;
        b = 32'h2222_2222;
        ifb = 1'b1;
        valid_i = 1'b1;
        @(posedge sys_clk);
        // Now assert reset
        alu_rst = 1'b1;
        @(posedge sys_clk);
        #1;
        if (valid_o !== 1'b0) begin
            $display("ERROR: valid_o not 0 after reset asserted");
            $finish;
        end
        // r should still be previous value (b = 0x22222222)
        if (r !== 32'h2222_2222) begin
            $display("ERROR: r changed on reset while valid_i high");
            $finish;
        end
        
        // Test selection logic combinational:
        // Change ifb, a, b before clock edge, ensure r updates accordingly on next edge.
        alu_rst = 1'b0;
        a = 32'h3333_3333;
        b = 32'h4444_4444;
        // Set ifb to select a
        ifb = 1'b1;
        @(posedge sys_clk);
        #1;
        if (r !== a) begin
            $display("ERROR: r not a after edge");
            $finish;
        end
        // Change to select b without clock edge: r should not change
        ifb = 1'b0;
        #5;
        if (r !== a) begin
            $display("ERROR: r changed before clock edge");
            $finish;
        end
        // Clock edge with new ifb
        @(posedge sys_clk);
        #1;
        if (r !== b) begin
            $display("ERROR: r not b after edge with b");
            $finish;
        end
        
        // Test that valid_o follows valid_i independent of clock? Actually valid_o is registered, so it follows valid_i on clock edge.
        // We'll test that.
        // Set valid_i low, no clock edge, valid_o should remain previous high value.
        valid_i = 1'b0;
        #5;
        if (valid_o !== 1'b1) begin
            $display("ERROR: valid_o changed without clock edge");
            $finish;
        end
        // Clock edge with valid_i low
        @(posedge sys_clk);
        #1;
        if (valid_o !== 1'b0) begin
            $display("ERROR: valid_o not 0 after clock edge with low valid_i");
            $finish;
        end
        
        $display("All tests passed");
        $finish;
    end

endmodule
