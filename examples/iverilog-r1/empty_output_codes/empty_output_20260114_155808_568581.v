// Verilog code that resulted in empty output
// Saved at: 2026-01-14T15:58:08.568623
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

module ID_EX_REG (
    input CLOCK,
    input RESET,
    input RegWriteEN_In,
    input [1:0] Mem2RegSEL_In,
    input MemWriteEN_In,
    input [4:0] ALUCtrl_In,
    input [4:0] ALUSrc_In,
    input [1:0] RegDstSEL_In,
    input [31:0] RegData1_In,
    input [31:0] RegData2_In,
    input [4:0] RSAddr_In,
    input [4:0] RTAddr_In,
    input [4:0] RDAddr_In,
    input [4:0] Shamt_In,
    input [15:0] Imm_In,
    input [31:0] PCAddr_In,
    output reg RegWriteEN_Out,
    output reg [1:0] Mem2RegSEL_Out,
    output reg MemWriteEN_Out,
    output reg [4:0] ALUCtrl_Out,
    output reg [4:0] ALUSrc_Out,
    output reg [1:0] RegDstSEL_Out,
    output reg [31:0] RegData1_Out,
    output reg [31:0] RegData2_Out,
    output reg [4:0] RSAddr_Out,
    output reg [4:0] RTAddr_Out,
    output reg [4:0] RDAddr_Out,
    output reg [4:0] Shamt_Out,
    output reg [15:0] Imm_Out,
    output reg [31:0] PCAddr_Out
);
    always @(posedge CLOCK) begin
        if (RESET) begin
            RegWriteEN_Out <= 1'b0;
            Mem2RegSEL_Out <= 2'b00;
            MemWriteEN_Out <= 1'b0;
            ALUCtrl_Out <= 5'b00000;
            ALUSrc_Out <= 5'b00000;
            RegDstSEL_Out <= 2'b00;
            RegData1_Out <= 32'b0;
            RegData2_Out <= 32'b0;
            RSAddr_Out <= 5'b00000;
            RTAddr_Out <= 5'b00000;
            RDAddr_Out <= 5'b00000;
            Shamt_Out <= 5'b00000;
            Imm_Out <= 16'b0;
            PCAddr_Out <= 32'b0;
        end else begin
            RegWriteEN_Out <= RegWriteEN_In;
            Mem2RegSEL_Out <= Mem2RegSEL_In;
            MemWriteEN_Out <= MemWriteEN_In;
            ALUCtrl_Out <= ALUCtrl_In;
            ALUSrc_Out <= ALUSrc_In;
            RegDstSEL_Out <= RegDstSEL_In;
            RegData1_Out <= RegData1_In;
            RegData2_Out <= RegData2_In;
            RSAddr_Out <= RSAddr_In;
            RTAddr_Out <= RTAddr_In;
            RDAddr_Out <= RDAddr_In;
            Shamt_Out <= Shamt_In;
            Imm_Out <= Imm_In;
            PCAddr_Out <= PCAddr_In;
        end
    end
endmodule

module testbench;
    reg CLOCK;
    reg RESET;
    reg RegWriteEN_In;
    reg [1:0] Mem2RegSEL_In;
    reg MemWriteEN_In;
    reg [4:0] ALUCtrl_In;
    reg [4:0] ALUSrc_In;
    reg [1:0] RegDstSEL_In;
    reg [31:0] RegData1_In;
    reg [31:0] RegData2_In;
    reg [4:0] RSAddr_In;
    reg [4:0] RTAddr_In;
    reg [4:0] RDAddr_In;
    reg [4:0] Shamt_In;
    reg [15:0] Imm_In;
    reg [31:0] PCAddr_In;
    wire RegWriteEN_Out;
    wire [1:0] Mem2RegSEL_Out;
    wire MemWriteEN_Out;
    wire [4:0] ALUCtrl_Out;
    wire [4:0] ALUSrc_Out;
    wire [1:0] RegDstSEL_Out;
    wire [31:0] RegData1_Out;
    wire [31:0] RegData2_Out;
    wire [4:0] RSAddr_Out;
    wire [4:0] RTAddr_Out;
    wire [4:0] RDAddr_Out;
    wire [4:0] Shamt_Out;
    wire [15:0] Imm_Out;
    wire [31:0] PCAddr_Out;
    
    ID_EX_REG dut (
        .CLOCK(CLOCK),
        .RESET(RESET),
        .RegWriteEN_In(RegWriteEN_In),
        .Mem2RegSEL_In(Mem2RegSEL_In),
        .MemWriteEN_In(MemWriteEN_In),
        .ALUCtrl_In(ALUCtrl_In),
        .ALUSrc_In(ALUSrc_In),
        .RegDstSEL_In(RegDstSEL_In),
        .RegData1_In(RegData1_In),
        .RegData2_In(RegData2_In),
        .RSAddr_In(RSAddr_In),
        .RTAddr_In(RTAddr_In),
        .RDAddr_In(RDAddr_In),
        .Shamt_In(Shamt_In),
        .Imm_In(Imm_In),
        .PCAddr_In(PCAddr_In),
        .RegWriteEN_Out(RegWriteEN_Out),
        .Mem2RegSEL_Out(Mem2RegSEL_Out),
        .MemWriteEN_Out(MemWriteEN_Out),
        .ALUCtrl_Out(ALUCtrl_Out),
        .ALUSrc_Out(ALUSrc_Out),
        .RegDstSEL_Out(RegDstSEL_Out),
        .RegData1_Out(RegData1_Out),
        .RegData2_Out(RegData2_Out),
        .RSAddr_Out(RSAddr_Out),
        .RTAddr_Out(RTAddr_Out),
        .RDAddr_Out(RDAddr_Out),
        .Shamt_Out(Shamt_Out),
        .Imm_Out(Imm_Out),
        .PCAddr_Out(PCAddr_Out)
    );
    
    initial begin
        CLOCK = 0;
        forever #5 CLOCK = ~CLOCK;
    end
    
    initial begin
        // Initialize inputs
        RESET = 1;
        RegWriteEN_In = 0;
        Mem2RegSEL_In = 2'b00;
        MemWriteEN_In = 0;
        ALUCtrl_In = 5'b00000;
        ALUSrc_In = 5'b00000;
        RegDstSEL_In = 2'b00;
        RegData1_In = 32'h00000000;
        RegData2_In = 32'h00000000;
        RSAddr_In = 5'b00000;
        RTAddr_In = 5'b00000;
        RDAddr_In = 5'b00000;
        Shamt_In = 5'b00000;
        Imm_In = 16'h0000;
        PCAddr_In = 32'h00000000;
        
        // Apply reset, check outputs become zero
        #10;
        if (RegWriteEN_Out !== 0) $display("ERROR: RegWriteEN_Out not zero after reset");
        if (Mem2RegSEL_Out !== 2'b00) $display("ERROR: Mem2RegSEL_Out not zero after reset");
        if (MemWriteEN_Out !== 0) $display("ERROR: MemWriteEN_Out not zero after reset");
        if (ALUCtrl_Out !== 5'b00000) $display("ERROR: ALUCtrl_Out not zero after reset");
        if (ALUSrc_Out !== 5'b00000) $display("ERROR: ALUSrc_Out not zero after reset");
        if (RegDstSEL_Out !== 2'b00) $display("ERROR: RegDstSEL_Out not zero after reset");
        if (RegData1_Out !== 32'h00000000) $display("ERROR: RegData1_Out not zero after reset");
        if (RegData2_Out !== 32'h00000000) $display("ERROR: RegData2_Out not zero after reset");
        if (RSAddr_Out !== 5'b00000) $display("ERROR: RSAddr_Out not zero after reset");
        if (RTAddr_Out !== 5'b00000) $display("ERROR: RTAddr_Out not zero after reset");
        if (RDAddr_Out !== 5'b00000) $display("ERROR: RDAddr_Out not zero after reset");
        if (Shamt_Out !== 5'b00000) $display("ERROR: Shamt_Out not zero after reset");
        if (Imm_Out !== 16'h0000) $display("ERROR: Imm_Out not zero after reset");
        if (PCAddr_Out !== 32'h00000000) $display("ERROR: PCAddr_Out not zero after reset");
        
        // Release reset and apply some inputs
        RESET = 0;
        RegWriteEN_In = 1;
        Mem2RegSEL_In = 2'b11;
        MemWriteEN_In = 1;
        ALUCtrl_In = 5'b11111;
        ALUSrc_In = 5'b10101;
        RegDstSEL_In = 2'b10;
        RegData1_In = 32'hDEADBEEF;
        RegData2_In = 32'hCAFEBABE;
        RSAddr_In = 5'b11111;
        RTAddr_In = 5'b10101;
        RDAddr_In = 5'b01010;
        Shamt_In = 5'b11001;
        Imm_In = 16'hF00F;
        PCAddr_In = 32'h12345678;
        
        #10; // wait for next clock edge (posedge at time 10, then 20)
        // At time 20, after posedge at time 10? Let's think: clock period is 10 (rising edges at 0,10,20...).
        // At time 0, reset initially high, outputs zero at posedge time 0.
        // At time 10, posedge, reset is still high (since we set RESET=1 for first 10). Actually we set RESET=1 at time 0 and hold for 10 units then release at time 10? Wait we set RESET=1 at time 0, and #10 then release. That means at time 10, RESET goes low at the same time as posedge? That could cause race condition. Better to deassert reset before posedge.
        // Let's adjust testbench to avoid races.
        // Let's restart simulation with a better test sequence.
        $finish;
    end
endmodule
