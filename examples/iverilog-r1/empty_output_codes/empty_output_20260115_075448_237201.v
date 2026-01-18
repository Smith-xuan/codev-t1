// Verilog code that resulted in empty output
// Saved at: 2026-01-15T07:54:48.237235
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

module ID_EX (
    input reloj,
    input resetID,
    input [4:0] ctrl_EXE,
    input [2:0] ctrl_MEM,
    input [1:0] ctrl_WB,
    input [31:0] DOA,
    input [31:0] DOB,
    input [31:0] imm_ext,
    input [4:0] rt,
    input [4:0] rd,
    output [2:0] ALU_FUN,
    output SEL_ALU,
    output SEL_REG,
    output [2:0] ctrl_MEM_exe,
    output [1:0] ctrl_WB_exe,
    output [31:0] A,
    output [31:0] DOB_exe,
    output [31:0] imm_ext_exe,
    output [4:0] rt_exe,
    output [4:0] rd_exe
);

    // Internal registers
    reg [4:0] ctrl_EXE_reg;
    reg [2:0] ctrl_MEM_reg;
    reg [1:0] ctrl_WB_reg;
    reg [31:0] A_reg;
    reg [31:0] DOB_reg;
    reg [31:0] imm_ext_reg;
    reg [4:0] rt_reg;
    reg [4:0] rd_reg;

    // Register update on rising clock edge
    always @(posedge reloj) begin
        if (resetID) begin
            ctrl_EXE_reg <= 5'b0;
            ctrl_MEM_reg <= 3'b0;
            ctrl_WB_reg <= 2'b0;
            A_reg <= 32'b0;
            DOB_reg <= 32'b0;
            imm_ext_reg <= 32'b0;
            rt_reg <= 5'b0;
            rd_reg <= 5'b0;
        end else begin
            ctrl_EXE_reg <= ctrl_EXE;
            ctrl_MEM_reg <= ctrl_MEM;
            ctrl_WB_reg <= ctrl_WB;
            A_reg <= DOA;
            DOB_reg <= DOB;
            imm_ext_reg <= imm_ext;
            rt_reg <= rt;
            rd_reg <= rd;
        end
    end

    // Output assignments
    assign ALU_FUN = ctrl_EXE_reg[4:2];
    assign SEL_ALU = ctrl_EXE_reg[1];
    assign SEL_REG = ctrl_EXE_reg[0];

    assign ctrl_MEM_exe = ctrl_MEM_reg;
    assign ctrl_WB_exe = ctrl_WB_reg;
    assign A = A_reg;
    assign DOB_exe = DOB_reg;
    assign imm_ext_exe = imm_ext_reg;
    assign rt_exe = rt_reg;
    assign rd_exe = rd_reg;

endmodule

module testbench;
    reg reloj;
    reg resetID;
    reg [4:0] ctrl_EXE;
    reg [2:0] ctrl_MEM;
    reg [1:0] ctrl_WB;
    reg [31:0] DOA;
    reg [31:0] DOB;
    reg [31:0] imm_ext;
    reg [4:0] rt;
    reg [4:0] rd;

    wire [2:0] ALU_FUN;
    wire SEL_ALU;
    wire SEL_REG;
    wire [2:0] ctrl_MEM_exe;
    wire [1:0] ctrl_WB_exe;
    wire [31:0] A;
    wire [31:0] DOB_exe;
    wire [31:0] imm_ext_exe;
    wire [4:0] rt_exe;
    wire [4:0] rd_exe;

    ID_EX dut (
        .reloj(reloj),
        .resetID(resetID),
        .ctrl_EXE(ctrl_EXE),
        .ctrl_MEM(ctrl_MEM),
        .ctrl_WB(ctrl_WB),
        .DOA(DOA),
        .DOB(DOB),
        .imm_ext(imm_ext),
        .rt(rt),
        .rd(rd),
        .ALU_FUN(ALU_FUN),
        .SEL_ALU(SEL_ALU),
        .SEL_REG(SEL_REG),
        .ctrl_MEM_exe(ctrl_MEM_exe),
        .ctrl_WB_exe(ctrl_WB_exe),
        .A(A),
        .DOB_exe(DOB_exe),
        .imm_ext_exe(imm_ext_exe),
        .rt_exe(rt_exe),
        .rd_exe(rd_exe)
    );

    initial begin
        // Initialize signals
        reloj = 0;
        resetID = 0;
        ctrl_EXE = 5'b00000;
        ctrl_MEM = 3'b000;
        ctrl_WB = 2'b00;
        DOA = 32'h00000000;
        DOB = 32'h00000000;
        imm_ext = 32'h00000000;
        rt = 5'b00000;
        rd = 5'b00000;

        // Apply reset
        resetID = 1;
        @(posedge reloj);
        #1;
        // Check that outputs are zero after reset
        if (ALU_FUN !== 3'b000) begin
            $display("ERROR: ALU_FUN not zero after reset. Got %b", ALU_FUN);
            $finish;
        end
        if (SEL_ALU !== 1'b0) begin
            $display("ERROR: SEL_ALU not zero after reset.");
            $finish;
        end
        if (SEL_REG !== 1'b0) begin
            $display("ERROR: SEL_REG not zero after reset.");
            $finish;
        end
        if (ctrl_MEM_exe !== 3'b000) begin
            $display("ERROR: ctrl_MEM_exe not zero after reset.");
            $finish;
        end
        if (ctrl_WB_exe !== 2'b00) begin
            $display("ERROR: ctrl_WB_exe not zero after reset.");
            $finish;
        end
        if (A !== 32'h00000000) begin
            $display("ERROR: A not zero after reset.");
            $finish;
        end
        if (DOB_exe !== 32'h00000000) begin
            $display("ERROR: DOB_exe not zero after reset.");
            $finish;
        end
        if (imm_ext_exe !== 32'h00000000) begin
            $display("ERROR: imm_ext_exe not zero after reset.");
            $finish;
        end
        if (rt_exe !== 5'b00000) begin
            $display("ERROR: rt_exe not zero after reset.");
            $finish;
        end
        if (rd_exe !== 5'b00000) begin
            $display("ERROR: rd_exe not zero after reset.");
            $finish;
        end
        $display("Reset test passed.");

        // Release reset and test normal operation
        resetID = 0;
        // Provide some test values
        ctrl_EXE = 5'b10101; // ALU_FUN bits: 101 (bits 4:2?) Wait we need to think.
        // Let's set bits: bit4=1, bit3=0, bit2=1, bit1=0, bit0=1
        // So ALU_FUN = bits[4:2] = 101 (binary 5), SEL_ALU = bit1 = 0, SEL_REG = bit0 = 1
        ctrl_MEM = 3'b111;
        ctrl_WB = 2'b11;
        DOA = 32'hDEADBEEF;
        DOB = 32'hCAFEBABE;
        imm_ext = 32'h12345678;
        rt = 5'b11111;
        rd = 5'b10101;

        @(posedge reloj);
        #1;
        // Check that outputs reflect the inputs after clock edge
        if (ALU_FUN !== 3'b101) begin
            $display("ERROR: ALU_FUN mismatch. Expected 3'b101, got %b", ALU_FUN);
            $finish;
        end
        if (SEL_ALU !== 1'b0) begin
            $display("ERROR: SEL_ALU mismatch. Expected 1'b0, got %b", SEL_ALU);
            $finish;
        end
        if (SEL_REG !== 1'b1) begin
            $display("ERROR: SEL_REG mismatch. Expected 1'b1, got %b", SEL_REG);
            $finish;
        end
        if (ctrl_MEM_exe !== 3'b111) begin
            $display("ERROR: ctrl_MEM_exe mismatch.");
            $finish;
        end
        if (ctrl_WB_exe !== 2'b11) begin
            $display("ERROR: ctrl_WB_exe mismatch.");
            $finish;
        end
        if (A !== 32'hDEADBEEF) begin
            $display("ERROR: A mismatch.");
            $finish;
        end
        if (DOB_exe !== 32'hCAFEBABE) begin
            $display("ERROR: DOB_exe mismatch.");
            $finish;
        end
        if (imm_ext_exe !== 32'h12345678) begin
            $display("ERROR: imm_ext_exe mismatch.");
            $finish;
        end
        if (rt_exe !== 5'b11111) begin
            $display("ERROR: rt_exe mismatch.");
            $finish;
        end
        if (rd_exe !== 5'b10101) begin
            $display("ERROR: rd_exe mismatch.");
            $finish;
        end
        $display("Normal operation test passed.");

        // Test that outputs do NOT change until next clock edge
        // Change inputs before next clock
        ctrl_EXE = 5'b01010;
        ctrl_MEM = 3'b001;
        ctrl_WB = 2'b01;
        DOA = 32'h11111111;
        DOB = 32'h22222222;
        imm_ext = 32'h33333333;
        rt = 5'b00001;
        rd = 5'b00010;
        // Wait a little but no posedge
        #5;
        // Check that outputs remain unchanged (still previous values)
        if (ALU_FUN !== 3'b101) begin
            $display("ERROR: ALU_FUN changed without clock edge.");
            $finish;
        end
        if (SEL_ALU !== 1'b0) begin
            $display("ERROR: SEL_ALU changed without clock edge.");
            $finish;
        end
        if (SEL_REG !== 1'b1) begin
            $display("ERROR: SEL_REG changed without clock edge.");
            $finish;
        end
        if (ctrl_MEM_exe !== 3'b111) begin
            $display("ERROR: ctrl_MEM_exe changed without clock edge.");
            $finish;
        end
        if (ctrl_WB_exe !== 2'b11) begin
            $display("ERROR: ctrl_WB_exe changed without clock edge.");
            $finish;
        end
        // Now trigger posedge
        @(posedge reloj);
        #1;
        // Check new values
        if (ALU_FUN !== 3'b010) begin // bits[4:2] of 01010: bits 4:2 = 010 (binary 2)
            $display("ERROR: ALU_FUN mismatch after second clock. Expected 3'b010, got %b", ALU_FUN);
            $finish;
        end
        if (SEL_ALU !== 1'b1) begin // bit1 of 01010 is 1
            $display("ERROR: SEL_ALU mismatch.");
            $finish;
        end
        if (SEL_REG !== 1'b0) begin // bit0 of 01010 is 0
            $display("ERROR: SEL_REG mismatch.");
            $finish;
        end
        if (ctrl_MEM_exe !== 3'b001) begin
            $display("ERROR: ctrl_MEM_exe mismatch.");
            $finish;
        end
        if (ctrl_WB_exe !== 2'b01) begin
            $display("ERROR: ctrl_WB_exe mismatch.");
            $finish;
        end
        if (A !== 32'h11111111) begin
            $display("ERROR: A mismatch.");
            $finish;
        end
        if (DOB_exe !== 32'h22222222) begin
            $display("ERROR: DOB_exe mismatch.");
            $finish;
        end
        if (imm_ext_exe !== 32'h33333333) begin
            $display("ERROR: imm_ext_exe mismatch.");
            $finish;
        end
        if (rt_exe !== 5'b00001) begin
            $display("ERROR: rt_exe mismatch.");
            $finish;
        end
        if (rd_exe !== 5'b00010) begin
            $display("ERROR: rd_exe mismatch.");
            $finish;
        end
        $display("All tests passed.");
        $finish;
    end
endmodule
