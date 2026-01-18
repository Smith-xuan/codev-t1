// Verilog code that resulted in empty output
// Saved at: 2026-01-13T20:43:34.117338
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

module MEM_WB (
    input IRegWrite,
    input [1:0] IRegStore,
    input [15:0] IPCP2,
    input [15:0] IALUResult,
    input [15:0] IStoreMem,
    input [2:0] IRd,
    input CLK,
    input Reset,
    input RegWrite,
    output reg ORegWrite,
    output reg [1:0] ORegStore,
    output reg [15:0] OPCP2,
    output reg [15:0] OALUResult,
    output reg [15:0] OStoreMem,
    output reg [2:0] ORd
);

always @(posedge CLK) begin
    if (Reset) begin
        ORegWrite <= 1'b0;
        ORegStore <= 2'b00;
        OPCP2 <= 16'b0;
        OALUResult <= 16'b0;
        OStoreMem <= 16'b0;
        ORd <= 3'b000;
    end else if (RegWrite) begin
        ORegWrite <= IRegWrite;
        ORegStore <= IRegStore;
        OPCP2 <= IPCP2;
        OALUResult <= IALUResult;
        OStoreMem <= IStoreMem;
        ORd <= IRd;
    end
    // If RegWrite is 0, outputs retain previous values (implicit)
end

endmodule

module testbench;
    reg IRegWrite;
    reg [1:0] IRegStore;
    reg [15:0] IPCP2;
    reg [15:0] IALUResult;
    reg [15:0] IStoreMem;
    reg [2:0] IRd;
    reg CLK;
    reg Reset;
    reg RegWrite;
    
    wire ORegWrite;
    wire [1:0] ORegStore;
    wire [15:0] OPCP2;
    wire [15:0] OALUResult;
    wire [15:0] OStoreMem;
    wire [2:0] ORd;
    
    MEM_WB dut (
        .IRegWrite(IRegWrite),
        .IRegStore(IRegStore),
        .IPCP2(IPCP2),
        .IALUResult(IALUResult),
        .IStoreMem(IStoreMem),
        .IRd(IRd),
        .CLK(CLK),
        .Reset(Reset),
        .RegWrite(RegWrite),
        .ORegWrite(ORegWrite),
        .ORegStore(ORegStore),
        .OPCP2(OPCP2),
        .OALUResult(OALUResult),
        .OStoreMem(OStoreMem),
        .ORd(ORd)
    );
    
    initial begin
        // Initialize inputs
        CLK = 0;
        Reset = 0;
        RegWrite = 0;
        IRegWrite = 0;
        IRegStore = 0;
        IPCP2 = 0;
        IALUResult = 0;
        IStoreMem = 0;
        IRd = 0;
        
        // Test 1: Reset asserted
        Reset = 1;
        @(posedge CLK);
        // After posedge, outputs should be zero
        #1;
        if (ORegWrite !== 0 || ORegStore !== 0 || OPCP2 !== 0 || OALUResult !== 0 || OStoreMem !== 0 || ORd !== 0) begin
            $display("FAIL: Reset not working");
            $finish;
        end
        $display("PASS: Reset test");
        
        // Test 2: Deassert reset, RegWrite active, pass inputs
        Reset = 0;
        RegWrite = 1;
        IRegWrite = 1;
        IRegStore = 2'b10;
        IPCP2 = 16'h1234;
        IALUResult = 16'h5678;
        IStoreMem = 16'h9ABC;
        IRd = 3'b101;
        @(posedge CLK);
        #1;
        if (ORegWrite !== 1 || ORegStore !== 2'b10 || OPCP2 !== 16'h1234 || OALUResult !== 16'h5678 || OStoreMem !== 16'h9ABC || ORd !== 3'b101) begin
            $display("FAIL: Normal pass-through not working");
            $display("  Expected ORegWrite=1, got %b", ORegWrite);
            $display("  Expected ORegStore=2'b10, got %b", ORegStore);
            $display("  Expected OPCP2=16'h1234, got %h", OPCP2);
            $display("  Expected OALUResult=16'h5678, got %h", OALUResult);
            $display("  Expected OStoreMem=16'h9ABC, got %h", OStoreMem);
            $display("  Expected ORd=3'b101, got %b", ORd);
            $finish;
        end
        $display("PASS: Normal pass-through test");
        
        // Test 3: RegWrite inactive, outputs should hold previous values
        RegWrite = 0;
        IRegWrite = 0; // Change inputs, should not affect outputs
        IRegStore = 2'b01;
        IPCP2 = 16'hFFFF;
        IALUResult = 16'hEEEE;
        IStoreMem = 16'hDDDD;
        IRd = 3'b111;
        @(posedge CLK);
        #1;
        if (ORegWrite !== 1 || ORegStore !== 2'b10 || OPCP2 !== 16'h1234 || OALUResult !== 16'h5678 || OStoreMem !== 16'h9ABC || ORd !== 3'b101) begin
            $display("FAIL: Hold behavior not working");
            $finish;
        end
        $display("PASS: Hold behavior test");
        
        // Test 4: After another clock with RegWrite active, new values should be latched
        RegWrite = 1;
        IRegWrite = 0;
        IRegStore = 2'b01;
        IPCP2 = 16'h1111;
        IALUResult = 16'h2222;
        IStoreMem = 16'h3333;
        IRd = 3'b010;
        @(posedge CLK);
        #1;
        if (ORegWrite !== 0 || ORegStore !== 2'b01 || OPCP2 !== 16'h1111 || OALUResult !== 16'h2222 || OStoreMem !== 16'h3333 || ORd !== 3'b010) begin
            $display("FAIL: New pass-through not working");
            $finish;
        end
        $display("PASS: New pass-through test");
        
        $display("All tests passed!");
        $finish;
    end
    
endmodule
