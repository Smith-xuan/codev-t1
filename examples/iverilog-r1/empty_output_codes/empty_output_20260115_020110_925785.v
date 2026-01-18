// Verilog code that resulted in empty output
// Saved at: 2026-01-15T02:01:10.925811
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

module PipelineReg_EXMEM (
  input [7:0] alu_result,
  input [7:0] data_to_mem,
  input [3:0] reg_dest,
  input rd_en,
  input wr_en,
  input mem_to_reg,
  input reg_write,
  input rst,
  input branch,
  input nclk,
  output [23:0] data_out
);

  reg [23:0] data_reg;

  always @(posedge nclk) begin
    if (rst) begin
      data_reg <= 24'b0;
    end else if (!branch) begin
      // Store all fields
      data_reg[7:0] <= alu_result;
      data_reg[15:8] <= data_to_mem;
      data_reg[19:16] <= reg_dest;
      data_reg[23:20] <= {reg_write, rd_en, wr_en, mem_to_reg};
    end
    // else keep data_reg unchanged (implicit)
  end

  assign data_out = data_reg;

endmodule

module testbench;
  reg [7:0] alu_result;
  reg [7:0] data_to_mem;
  reg [3:0] reg_dest;
  reg rd_en;
  reg wr_en;
  reg mem_to_reg;
  reg reg_write;
  reg rst;
  reg branch;
  reg nclk;
  wire [23:0] data_out;

  PipelineReg_EXMEM dut (
    .alu_result(alu_result),
    .data_to_mem(data_to_mem),
    .reg_dest(reg_dest),
    .rd_en(rd_en),
    .wr_en(wr_en),
    .mem_to_reg(mem_to_reg),
    .reg_write(reg_write),
    .rst(rst),
    .branch(branch),
    .nclk(nclk),
    .data_out(data_out)
  );

  initial begin
    // Initialize signals
    nclk = 0;
    rst = 0;
    branch = 0;
    alu_result = 8'h00;
    data_to_mem = 8'h00;
    reg_dest = 4'h0;
    rd_en = 0;
    wr_en = 0;
    mem_to_reg = 0;
    reg_write = 0;

    // Apply reset
    rst = 1;
    @(posedge nclk);
    rst = 0;
    @(posedge nclk);
    // Check reset values: data_out should be 0
    if (data_out !== 24'h0) begin
      $display("ERROR: Reset failed. data_out = %h", data_out);
      $finish;
    end

    // Test 1: Store all fields when branch is not active
    alu_result = 8'hAA;
    data_to_mem = 8'hBB;
    reg_dest = 4'hC;
    rd_en = 1;
    wr_en = 0;
    mem_to_reg = 1;
    reg_write = 1;
    branch = 0;
    @(posedge nclk);
    // Expected data_out = {reg_write, rd_en, wr_en, mem_to_reg, reg_dest, data_to_mem, alu_result}
    // = {1'b1, 1'b1, 1'b0, 1'b1, 4'hC, 8'hBB, 8'hAA}
    // bits [23:20] = 1_1_0_1 = 4'b1101 (13)
    // bits [19:16] = 4'hC
    // bits [15:8] = 8'hBB
    // bits [7:0] = 8'hAA
    // So total 24'hD_C_BB_AA? Let's compute: concatenation order: {reg_write, rd_en, wr_en, mem_to_reg} = 4'b1101 = 0xD
    // Then 4'hC = 0xC, then 8'hBB = 0xBB, then 8'hAA = 0xAA.
    // So 24-bit value = 24'hD_C_BB_AA? Actually, hex representation: {4'hD, 4'hC, 8'hBB, 8'hAA} = 24'hDCBBAA.
    // Wait: 4 bits D, 4 bits C, 8 bits BB, 8 bits AA -> combined: D C BB AA.
    // Let's compute: D = 1101, C = 1100, BB = 10111011, AA = 10101010.
    // Concatenated: 1101 1100 10111011 10101010 = 110111001011101110101010 binary.
    // Hex: DCBBAA.
    // Let's verify using Verilog.
    #1;
    if (data_out !== 24'hDCBBAA) begin
      $display("ERROR: Test 1 failed. Expected 24'hDCBBAA, got %h", data_out);
      $finish;
    end

    // Test 2: When branch is active, register should not update (hold previous value)
    // Change inputs while branch = 1
    branch = 1;
    alu_result = 8'h11;
    data_to_mem = 8'h22;
    reg_dest = 4'h3;
    rd_en = 0;
    wr_en = 1;
    mem_to_reg = 0;
    reg_write = 0;
    @(posedge nclk);
    #1;
    // Should still be previous value DCBBAA
    if (data_out !== 24'hDCBBAA) begin
      $display("ERROR: Test 2 failed. data_out changed when branch active. Got %h", data_out);
      $finish;
    end

    // Test 3: When branch is not active again, new values should be stored
    branch = 0;
    alu_result = 8'h55;
    data_to_mem = 8'h66;
    reg_dest = 4'h7;
    rd_en = 1;
    wr_en = 1;
    mem_to_reg = 1;
    reg_write = 0;
    @(posedge nclk);
    #1;
    // Compute expected: {0,1,1,1} = 4'b0111 = 7, reg_dest = 7, data_to_mem = 66, alu_result = 55.
    // So 24'h7_7_66_55? Wait: {reg_write=0, rd_en=1, wr_en=1, mem_to_reg=1} = 4'b0111 = 7.
    // reg_dest = 7 = 4'h7.
    // data_to_mem = 8'h66.
    // alu_result = 8'h55.
    // Combined: 4'h7, 4'h7, 8'h66, 8'h55 => 24'h776655.
    if (data_out !== 24'h776655) begin
      $display("ERROR: Test 3 failed. Expected 24'h776655, got %h", data_out);
      $finish;
    end

    // Test 4: Reset again
    rst = 1;
    @(posedge nclk);
    rst = 0;
    #1;
    if (data_out !== 24'h0) begin
      $display("ERROR: Reset test failed. data_out = %h", data_out);
      $finish;
    end

    $display("All tests passed!");
    $finish;
  end

endmodule
