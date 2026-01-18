// Verilog code that resulted in empty output
// Saved at: 2026-01-15T01:53:41.995651
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

module Branch_Adder (
  input [31:0] PC,
  input [31:0] Imm,
  output [31:0] PC_target
);

wire [31:0] imm_shifted = {Imm[31], Imm[31:1]};
assign PC_target = PC + imm_shifted;

endmodule

module testbench;
  reg [31:0] PC;
  reg [31:0] Imm;
  wire [31:0] PC_target;
  reg [31:0] expected;
  integer errors;
  
  Branch_Adder dut (.PC(PC), .Imm(Imm), .PC_target(PC_target));
  
  task check;
    input string desc;
    begin
      @(negedge PC);
      #1;
      expected = $signed(Imm) >>> 1;
      expected = PC + expected;
      if (PC_target !== expected) begin
        $display("ERROR: %s", desc);
        $display("  PC = %h, Imm = %h, PC_target = %h, expected = %h", PC, Imm, PC_target, expected);
        errors = errors + 1;
      end else begin
        $display("OK: %s", desc);
      end
    end
  endtask
  
  initial begin
    errors = 0;
    
    // Test 1: zero offset
    PC = 32'h1000;
    Imm = 32'h00000000;
    #1 check("zero offset");
    
    // Test 2: positive offset (small)
    PC = 32'h2000;
    Imm = 32'h00000002; // 2
    // shift right by 1 => 1
    #1 check("positive small offset");
    
    // Test 3: positive offset (odd)
    PC = 32'h3000;
    Imm = 32'h00000003; // 3
    // shift right arithmetic => 1 (since 3 in two's complement positive, logical shift right)
    #1 check("positive odd offset");
    
    // Test 4: negative offset (positive -1)
    PC = 32'h4000;
    Imm = 32'hFFFFFFFF; // -1
    // shift right arithmetic => -1
    #1 check("negative offset -1");
    
    // Test 5: negative offset (large negative)
    PC = 32'h5000;
    Imm = 32'h80000000; // -2147483648
    // shift right arithmetic => -1073741824 (0xC0000000)
    #1 check("large negative offset");
    
    // Test 6: positive offset large
    PC = 32'h6000;
    Imm = 32'h7FFFFFFF; // maximum positive (2147483647)
    // shift right arithmetic => 1073741823 (0x3FFFFFFF)
    #1 check("large positive offset");
    
    // Test 7: negative odd offset (-3)
    PC = 32'h7000;
    Imm = 32'hFFFFFFFD; // -3
    // shift right arithmetic => -2 (arithmetic shift rounds towards negative infinity)
    #1 check("negative odd offset -3");
    
    // Test 8: PC zero
    PC = 32'h0;
    Imm = 32'h00000001; // 1
    // shift right => 0
    #1 check("PC zero");
    
    // Test 9: random values
    PC = 32'hAABBCCDD;
    Imm = 32'h12345678;
    #1 check("random offset");
    
    // Test 10: negative odd offset (-1) but PC non-zero
    PC = 32'h12345678;
    Imm = 32'hFFFFFFFF;
    #1 check("non-zero PC with -1 offset");
    
    if (errors == 0)
      $display("All tests passed!");
    else
      $display("Failed with %d errors", errors);
    $finish;
  end
endmodule
