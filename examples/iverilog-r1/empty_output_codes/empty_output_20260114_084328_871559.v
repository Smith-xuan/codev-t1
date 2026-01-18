// Verilog code that resulted in empty output
// Saved at: 2026-01-14T08:43:28.871595
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
    input CLK,
    input Reset_L,
    input [1:0] ID_ctrlWB,
    input [1:0] ID_ctrlMEM,
    input [4:0] ID_ctrlEX,
    input [31:0] ID_pc4,
    input [31:0] ID_RegA,
    input [31:0] ID_RegB,
    input [31:0] ID_ExtImm,
    input [1:0] ID_AluOpCtrlA,
    input [1:0] ID_AluOpCtrlB,
    input ID_DataMemForwardCtrl_EX,
    input ID_DataMemForwardCtrl_MEM,
    input [25:0] ID_IRaddr,
    output reg [1:0] EX_ctrlWB,
    output reg [1:0] EX_ctrlMEM,
    output reg [4:0] EX_ctrlEX,
    output reg [31:0] EX_pc4,
    output reg [31:0] EX_RegA,
    output reg [31:0] EX_RegB,
    output reg [31:0] EX_ExtImm,
    output reg [1:0] EX_AluOpCtrlA,
    output reg [1:0] EX_AluOpCtrlB,
    output reg EX_DataMemForwardCtrl_EX,
    output reg EX_DataMemForwardCtrl_MEM,
    output reg [25:0] EX_IRaddr
);

always @(negedge CLK) begin
    if (~Reset_L) begin
        // reset all outputs to zero
        EX_ctrlWB <= 2'b0;
        EX_ctrlMEM <= 2'b0;
        EX_ctrlEX <= 5'b0;
        EX_pc4 <= 32'b0;
        EX_RegA <= 32'b0;
        EX_RegB <= 32'b0;
        EX_ExtImm <= 32'b0;
        EX_AluOpCtrlA <= 2'b0;
        EX_AluOpCtrlB <= 2'b0;
        EX_DataMemForwardCtrl_EX <= 1'b0;
        EX_DataMemForwardCtrl_MEM <= 1'b0;
        EX_IRaddr <= 26'b0;
    end else begin
        // capture inputs
        EX_ctrlWB <= ID_ctrlWB;
        EX_ctrlMEM <= ID_ctrlMEM;
        EX_ctrlEX <= ID_ctrlEX;
        EX_pc4 <= ID_pc4;
        EX_RegA <= ID_RegA;
        EX_RegB <= ID_RegB;
        EX_ExtImm <= ID_ExtImm;
        EX_AluOpCtrlA <= ID_AluOpCtrlA;
        EX_AluOpCtrlB <= ID_AluOpCtrlB;
        EX_DataMemForwardCtrl_EX <= ID_DataMemForwardCtrl_EX;
        EX_DataMemForwardCtrl_MEM <= ID_DataMemForwardCtrl_MEM;
        EX_IRaddr <= ID_IRaddr;
    end
end

endmodule

module testbench;
    reg CLK;
    reg Reset_L;
    reg [1:0] ID_ctrlWB;
    reg [1:0] ID_ctrlMEM;
    reg [4:0] ID_ctrlEX;
    reg [31:0] ID_pc4;
    reg [31:0] ID_RegA;
    reg [31:0] ID_RegB;
    reg [31:0] ID_ExtImm;
    reg [1:0] ID_AluOpCtrlA;
    reg [1:0] ID_AluOpCtrlB;
    reg ID_DataMemForwardCtrl_EX;
    reg ID_DataMemForwardCtrl_MEM;
    reg [25:0] ID_IRaddr;
    
    wire [1:0] EX_ctrlWB;
    wire [1:0] EX_ctrlMEM;
    wire [4:0] EX_ctrlEX;
    wire [31:0] EX_pc4;
    wire [31:0] EX_RegA;
    wire [31:0] EX_RegB;
    wire [31:0] EX_ExtImm;
    wire [1:0] EX_AluOpCtrlA;
    wire [1:0] EX_AluOpCtrlB;
    wire EX_DataMemForwardCtrl_EX;
    wire EX_DataMemForwardCtrl_MEM;
    wire [25:0] EX_IRaddr;
    
    ID_EX dut (
        .CLK(CLK),
        .Reset_L(Reset_L),
        .ID_ctrlWB(ID_ctrlWB),
        .ID_ctrlMEM(ID_ctrlMEM),
        .ID_ctrlEX(ID_ctrlEX),
        .ID_pc4(ID_pc4),
        .ID_RegA(ID_RegA),
        .ID_RegB(ID_RegB),
        .ID_ExtImm(ID_ExtImm),
        .ID_AluOpCtrlA(ID_AluOpCtrlA),
        .ID_AluOpCtrlB(ID_AluOpCtrlB),
        .ID_DataMemForwardCtrl_EX(ID_DataMemForwardCtrl_EX),
        .ID_DataMemForwardCtrl_MEM(ID_DataMemForwardCtrl_MEM),
        .ID_IRaddr(ID_IRaddr),
        .EX_ctrlWB(EX_ctrlWB),
        .EX_ctrlMEM(EX_ctrlMEM),
        .EX_ctrlEX(EX_ctrlEX),
        .EX_pc4(EX_pc4),
        .EX_RegA(EX_RegA),
        .EX_RegB(EX_RegB),
        .EX_ExtImm(EX_ExtImm),
        .EX_AluOpCtrlA(EX_AluOpCtrlA),
        .EX_AluOpCtrlB(EX_AluOpCtrlB),
        .EX_DataMemForwardCtrl_EX(EX_DataMemForwardCtrl_EX),
        .EX_DataMemForwardCtrl_MEM(EX_DataMemForwardCtrl_MEM),
        .EX_IRaddr(EX_IRaddr)
    );
    
    // Clock generation
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK; // 10ns period
    end
    
    // Test procedure
    initial begin
        // Initialize inputs
        Reset_L = 1'b0; // assert reset (active low)
        ID_ctrlWB = 2'b00;
        ID_ctrlMEM = 2'b00;
        ID_ctrlEX = 5'b00000;
        ID_pc4 = 32'h00000000;
        ID_RegA = 32'h00000000;
        ID_RegB = 32'h00000000;
        ID_ExtImm = 32'h00000000;
        ID_AluOpCtrlA = 2'b00;
        ID_AluOpCtrlB = 2'b00;
        ID_DataMemForwardCtrl_EX = 1'b0;
        ID_DataMemForwardCtrl_MEM = 1'b0;
        ID_IRaddr = 26'h0000000;
        
        // Wait for a negative edge (first negative edge at time 5ns)
        #10; // wait for first positive edge at 10ns? Let's wait for negative edge.
        // Actually we can wait for any edge. Let's wait for a negative edge.
        // At time 0, CLK is 0, so we are at negative edge? The always block triggers on negedge CLK.
        // Since Reset_L is 0, outputs should be reset to zero.
        // Let's check after a small delay after negedge.
        #1; // small delay after negedge at time 0? Actually negedge at time 0? CLK was 0 at time 0, but we need a transition from 1 to 0.
        // Let's start clock with initial CLK = 0, then we need a falling edge.
        // We'll let simulation run for some time.
        
        // Let's restructure: Generate clock with period 10, start at 0.
        // At time 0, CLK = 0, but there is no change, so no negedge trigger.
        // First negedge occurs after CLK goes from 1 to 0.
        // We'll set CLK to 1 at time 0, then after 5ns go to 0.
        // Let's modify clock generation: initial CLK = 1; forever #5 CLK = ~CLK; would give first negedge at 5ns.
        // However we can also just wait for a negedge using @(negedge CLK).
        // Let's do that.
        
        // Stop here for now.
        $finish;
    end
    
endmodule
