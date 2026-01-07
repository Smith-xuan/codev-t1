// Verilog code that resulted in empty output
// Saved at: 2026-01-06T04:35:44.886741
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

module npc (
    input [31:0] pc,
    input [15:0] imm16,
    input branch,
    input zero,
    input jump,
    input [25:0] target,
    output reg [31:0] npc
);

    // Sign-extended and shifted immediate for branch
    wire [31:0] imm_ext = { {16{imm16[15]}}, imm16 };
    wire [31:0] imm_shift = imm_ext << 2;  // shift left by 2 (multiply by 4)

    // Shifted target for jump
    wire [27:0] target_shift = { target, 2'b00 };

    // Next PC selection
    always @* begin
        if (jump) begin
            npc = {pc[31:28], target_shift};  // jump address
        end else if (branch && zero) begin
            npc = pc + imm_shift;  // branch offset
        end else begin
            npc = pc + 32'd4;      // sequential
        end
    end

endmodule

module test_debug;
    reg [31:0] pc;
    reg [15:0] imm16;
    reg branch;
    reg zero;
    reg jump;
    reg [25:0] target;
    wire [31:0] npc;

    wire [31:0] imm_ext;
    wire [31:0] imm_shift;
    wire [27:0] target_shift;
    assign imm_ext = { {16{imm16[15]}}, imm16 };
    assign imm_shift = imm_ext << 2;
    assign target_shift = { target, 2'b00 };

    npc dut (.*);

    initial begin
        // Test jump
        pc = 32'h1234_5678;
        target = 26'h03ABCDE;
        branch = 0;
        zero = 0;
        jump = 1;
        #10;
        $display("pc=%h, target=%h (26-bit)", pc, target);
        $display("  imm_ext=%h", dut.npc_imm_ext); // cannot access internal signal
        // We'll compute manually
        $display("  target_shift computed: %h", target_shift);
        $display("  jump_addr = {pc[31:28]=%h, target_shift} = %h", pc[31:28], {pc[31:28], target_shift});
        $display("  npc output = %h", npc);
        // Check if target_shift equals target << 2
        $display("  target << 2 = %h", target << 2);
        $display("  target_shift vs target<<2: %s", (target_shift == (target << 2)) ? "EQUAL" : "NOT EQUAL");
        // Print full binary to see difference
        $display("  target    (26 bits): %b", target);
        $display("  target<<2 (28 bits): %b", target << 2);
        $display("  target_shift (28 bits): %b", target_shift);
        
        // Another jump with target = 0
        target = 0;
        #10;
        $display("\nSecond jump test:");
        $display("  target=%h", target);
        $display("  target_shift=%h", target_shift);
        $display("  target<<2=%h", target << 2);
        $display("  jump_addr=%h", {pc[31:28], target_shift});

        // Test branch negative immediate
        pc = 32'h0000_3000;
        imm16 = 16'hFFFC;
        branch = 1;
        zero = 1;
        jump = 0;
        #10;
        $display("\nBranch negative:");
        $display("  imm16=%h", imm16);
        $display("  imm_ext=%h", dut.npc_imm_ext); // still cannot access
        $display("  imm_shift=%h", dut.npc_imm_shift);
        $display("  expected branch_offset=%h", pc + imm16);
        $display("  npc=%h", npc);
        
        $finish;
    end
endmodule
module testbench;
    // dummy
endmodule
