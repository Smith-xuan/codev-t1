// Verilog code that resulted in empty output
// Saved at: 2026-01-15T05:17:41.437037
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

`timescale 1ns/1ps

module display_pane (
    input clk,
    input rst,
    input fifo_full,
    output fifo_wr_en,
    output [23:0] data2output_2,
    output [16:0] addr
);

reg [9:0] col; // 0-639 (10 bits)
reg [8:0] row; // 0-479 (9 bits)

// fifo_wr_en is simply the inverse of fifo_full
assign fifo_wr_en = ~fifo_full;

// address calculation: linear index 0..76799
wire [8:0] row_scaled = row >> 1; // divide by 2
wire [9:0] col_scaled = col >> 1; // divide by 2 (10 bits)
wire [16:0] addr_raw = row_scaled * 320 + col_scaled;
assign addr = addr_raw;

// data output: {15'b0, addr[7:0], fifo_full}
assign data2output_2 = {15'b0, addr[7:0], fifo_full};

// counter update logic
always @(posedge clk) begin
    if (rst) begin
        col <= 0;
        row <= 0;
    end else if (fifo_wr_en) begin
        // update column
        if (col == 10'd639) begin
            col <= 0;
            if (row == 9'd479) begin
                row <= 0;
            end else begin
                row <= row + 1;
            end
        end else begin
            col <= col + 1;
        end
    end
end

endmodule

module testbench;
    reg clk;
    reg rst;
    reg fifo_full;
    wire fifo_wr_en;
    wire [23:0] data2output_2;
    wire [16:0] addr;
    
    display_pane dut (
        .clk(clk),
        .rst(rst),
        .fifo_full(fifo_full),
        .fifo_wr_en(fifo_wr_en),
        .data2output_2(data2output_2),
        .addr(addr)
    );
    
    initial begin
        clk = 0;
        rst = 1;
        fifo_full = 1; // initially FIFO full, so no writes
        
        // Release reset after 20 ns
        #20 rst = 0;
        
        // Test scenario 1: FIFO not full, should increment counters
        #10 fifo_full = 0; // FIFO not full
        
        // Run for 15 clock cycles
        repeat (15) @(posedge clk);
        
        // Test scenario 2: FIFO becomes full again
        #10 fifo_full = 1;
        repeat (5) @(posedge clk);
        
        // Test scenario 3: FIFO not full again
        #10 fifo_full = 0;
        repeat (10) @(posedge clk);
        
        $finish;
    end
    
    always @(posedge clk) begin
        $display("Time %0t ns: col=%0d row=%0d addr=0x%0h fifo_wr_en=%b fifo_full=%b", 
                 $time, dut.col, dut.row, addr, fifo_wr_en, fifo_full);
    end
    
endmodule
