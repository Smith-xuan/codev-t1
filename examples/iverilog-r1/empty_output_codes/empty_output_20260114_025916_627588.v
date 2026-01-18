// Verilog code that resulted in empty output
// Saved at: 2026-01-14T02:59:16.627629
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

`timescale 1ns / 1ps

module PiSimulator_VGA (
    input clk25,
    output HS,
    output VS,
    output [9:0] px_x,
    output [9:0] px_y,
    output vidSel
);

    // Timing parameters
    parameter H_TOTAL = 800;
    parameter V_TOTAL = 525;
    parameter H_VISIBLE_START = 144;
    parameter H_VISIBLE_END = 783;
    parameter V_VISIBLE_START = 35;
    parameter V_VISIBLE_END = 514;
    parameter H_SYNC_START = 48;
    parameter H_SYNC_WIDTH = 96;
    parameter V_SYNC_START = 33;
    parameter V_SYNC_WIDTH = 2;
    
    // Counters
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;
    
    // Counter update
    always @(posedge clk25) begin
        if (h_count == H_TOTAL-1) begin
            h_count <= 0;
            if (v_count == V_TOTAL-1)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end else begin
            h_count <= h_count + 1;
        end
    end
    
    // Sync outputs (active low)
    assign HS = (h_count >= H_SYNC_START && h_count < H_SYNC_START + H_SYNC_WIDTH) ? 1'b0 : 1'b1;
    assign VS = (v_count >= V_SYNC_START && v_count < V_SYNC_START + V_SYNC_WIDTH) ? 1'b0 : 1'b1;
    
    // Visible area and pixel coordinates
    assign vidSel = (h_count >= H_VISIBLE_START && h_count <= H_VISIBLE_END) &&
                    (v_count >= V_VISIBLE_START && v_count <= V_VISIBLE_END);
    
    assign px_x = (h_count >= H_VISIBLE_START && h_count <= H_VISIBLE_END) ?
                  (h_count - H_VISIBLE_START) : 10'd0;
    
    assign px_y = (v_count >= V_VISIBLE_START && v_count <= V_VISIBLE_END) ?
                  (v_count - V_VISIBLE_START) : 10'd0;
    
endmodule

// Simple testbench - print only first few cycles
module testbench;
    reg clk25;
    wire HS, VS;
    wire [9:0] px_x, px_y;
    wire vidSel;
    
    PiSimulator_VGA dut (
        .clk25(clk25),
        .HS(HS),
        .VS(VS),
        .px_x(px_x),
        .px_y(px_y),
        .vidSel(vidSel)
    );
    
    // 25 MHz clock: period 40 ns
    initial begin
        clk25 = 0;
        #100; // wait a bit
        repeat (200) begin
            @(posedge clk25);
            #1; // sample after edge
            $display("Time=%0t, HS=%b, VS=%b, px_x=%0d, px_y=%0d, vidSel=%b", 
                     $time, HS, VS, px_x, px_y, vidSel);
        end
        $finish;
    end
endmodule
