// Verilog code that resulted in empty output
// Saved at: 2026-01-07T01:49:45.165281
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

module memory #(
    parameter W = 32,
    parameter D = 8,
    parameter NOP_INSTR = 32'h0000_0000
) (
    input  wire i_clk,
    input  wire i_reset,
    input  wire [D-1:0] i_addr,
    input  wire [W-1:0] i_data,
    input  wire i_mem_read,
    input  wire i_mem_write,
    output reg  [W-1:0] o_data
);

    localparam NUM_WORDS = (1 << (D-2));
    reg [W-1:0] mem [0:NUM_WORDS-1];
    wire [D-1:0] word_index = i_addr >> 2;

    always @(posedge i_clk) begin
        if (i_reset) begin
            o_data <= NOP_INSTR;
        end else begin
            if (i_mem_write) begin
                mem[word_index] <= i_data;
                o_data          <= i_data;
            end else if (i_mem_read) begin
                o_data <= mem[word_index];
            end
        end
    end
endmodule

module testbench;
    reg clk;
    reg reset;
    reg [7:0] addr;
    reg [31:0] data_in;
    reg read, write;
    wire [31:0] data_out;
    
    memory dut (.i_clk(clk), .i_reset(reset), .i_addr(addr), .i_data(data_in),
                .i_mem_read(read), .i_mem_write(write), .o_data(data_out));
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        reset = 1;
        #20 reset = 0;
        #10 write = 1; addr = 0; data_in = 32'h12345678;
        #10 write = 0; read = 1;
        #10 read = 0;
        #10 $finish;
    end
endmodule
