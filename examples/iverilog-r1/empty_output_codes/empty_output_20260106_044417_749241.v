// Verilog code that resulted in empty output
// Saved at: 2026-01-06T04:44:17.749277
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

`timescale 1ns/1ns

module WB (
    input wire clk_i,
    input wire n_rst_i,
    input wire [31:0] MEMWB_mem_i,
    input wire [31:0] MEMWB_alu_i,
    input wire [4:0] MEMWB_reg_write_address_i,
    input wire MEMWB_ctrl_reg_write_i,
    input wire MEMWB_ctrl_mem_to_reg_i,
    output reg [4:0] WB_reg_write_address_o,
    output reg [31:0] WB_reg_write_data_o,
    output reg WB_ctrl_reg_write_o
);

    // Combinational selection of write-back data
    wire [31:0] wb_data_mux;
    assign wb_data_mux = MEMWB_ctrl_mem_to_reg_i ? MEMWB_mem_i : MEMWB_alu_i;

    // Sequential registration
    always @(posedge clk_i or negedge n_rst_i) begin
        if (!n_rst_i) begin
            WB_reg_write_address_o <= 5'b0;
            WB_reg_write_data_o <= 32'b0;
            WB_ctrl_reg_write_o <= 1'b0;
        end else begin
            WB_reg_write_address_o <= MEMWB_reg_write_address_i;
            WB_reg_write_data_o <= wb_data_mux;
            WB_ctrl_reg_write_o <= MEMWB_ctrl_reg_write_i;
        end
    end

endmodule

module testbench;
    reg clk;
    reg n_rst;
    reg [31:0] MEMWB_mem_i;
    reg [31:0] MEMWB_alu_i;
    reg [4:0] MEMWB_reg_write_address_i;
    reg MEMWB_ctrl_reg_write_i;
    reg MEMWB_ctrl_mem_to_reg_i;
    wire [4:0] WB_reg_write_address_o;
    wire [31:0] WB_reg_write_data_o;
    wire WB_ctrl_reg_write_o;

    WB dut (
        .clk_i(clk),
        .n_rst_i(n_rst),
        .MEMWB_mem_i(MEMWB_mem_i),
        .MEMWB_alu_i(MEMWB_alu_i),
        .MEMWB_reg_write_address_i(MEMWB_reg_write_address_i),
        .MEMWB_ctrl_reg_write_i(MEMWB_ctrl_reg_write_i),
        .MEMWB_ctrl_mem_to_reg_i(MEMWB_ctrl_mem_to_reg_i),
        .WB_reg_write_address_o(WB_reg_write_address_o),
        .WB_reg_write_data_o(WB_reg_write_data_o),
        .WB_ctrl_reg_write_o(WB_ctrl_reg_write_o)
    );

    // Generate a few clock cycles
    initial begin
        clk = 0;
        #0;
        clk = 1; #5;
        clk = 0; #5;
        clk = 1; #5;
        clk = 0; #5;
        clk = 1; #5;
        clk = 0; #5;
        clk = 1; #5;
        clk = 0; #5;
        clk = 1; #5;
        clk = 0; #5;
        $finish;
    end

    // Test sequence
    initial begin
        // Initialize
        n_rst = 0;
        MEMWB_mem_i = 32'h0;
        MEMWB_alu_i = 32'h0;
        MEMWB_reg_write_address_i = 5'b0;
        MEMWB_ctrl_reg_write_i = 0;
        MEMWB_ctrl_mem_to_reg_i = 0;
        #1;
        
        // Check reset outputs are zero
        if (WB_reg_write_address_o !== 0 || WB_reg_write_data_o !== 0 || WB_ctrl_reg_write_o !== 0) begin
            $display("FAIL: Reset not zero");
            $finish;
        end
        
        // Release reset on next rising edge? Actually let's deassert reset now
        #4;
        n_rst = 1;
        // Now wait for a posedge
        #10; // at time 15, after posedge
        
        // Test ALU path
        MEMWB_reg_write_address_i = 5'h0A;
        MEMWB_ctrl_reg_write_i = 1;
        MEMWB_ctrl_mem_to_reg_i = 0;
        MEMWB_alu_i = 32'hDEADBEEF;
        MEMWB_mem_i = 32'h12345678;
        #10; // at time 25, after next posedge
        if (WB_reg_write_address_o !== 5'h0A) $display("FAIL: Addr mismatch");
        if (WB_reg_write_data_o !== 32'hDEADBEEF) $display("FAIL: Data mismatch");
        if (WB_ctrl_reg_write_o !== 1) $display("FAIL: Write control mismatch");
        
        // Test memory path
        MEMWB_ctrl_mem_to_reg_i = 1;
        MEMWB_mem_i = 32'hABCD1234;
        #10; // time 35
        if (WB_reg_write_address_o !== 5'h0A) $display("FAIL: Addr mismatch 2");
        if (WB_reg_write_data_o !== 32'hABCD1234) $display("FAIL: Data mismatch 2");
        
        // Test no write enable
        MEMWB_ctrl_reg_write_i = 0;
        MEMWB_ctrl_mem_to_reg_i = 0;
        MEMWB_alu_i = 32'h55555555;
        #10; // time 45
        if (WB_ctrl_reg_write_o !== 0) $display("FAIL: Write control not zero");
        
        // Test reset again
        n_rst = 0;
        #10; // time 55
        if (WB_reg_write_address_o !== 0 || WB_reg_write_data_o !== 0 || WB_ctrl_reg_write_o !== 0) begin
            $display("FAIL: Reset deassertion not zero");
        end
        
        $display("All tests passed");
        $finish;
    end

endmodule
