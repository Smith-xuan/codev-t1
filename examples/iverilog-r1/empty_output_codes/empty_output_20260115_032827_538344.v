// Verilog code that resulted in empty output
// Saved at: 2026-01-15T03:28:27.538368
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

module VGA_timings #(
    parameter H_DISPLAY_WIDTH = 640,
    parameter H_FRONT_PORCH = 16,
    parameter H_SYNC_WIDTH = 96,
    parameter H_BACK_PORCH = 48,
    parameter V_DISPLAY_WIDTH = 480,
    parameter V_FRONT_PORCH = 10,
    parameter V_SYNC_WIDTH = 2,
    parameter V_BACK_PORCH = 33
) (
    input iClk,
    input iClear,
    output oHS,
    output oVS,
    output [9:0] oCountH,
    output [9:0] oCountV
);

    localparam H_TOTAL = H_DISPLAY_WIDTH + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;
    localparam V_TOTAL = V_DISPLAY_WIDTH + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;

    reg [9:0] oCountH_reg;
    reg [9:0] oCountV_reg;

    always @(posedge iClk) begin
        if (iClear) begin
            oCountH_reg <= 0;
            oCountV_reg <= 0;
        end else begin
            if (oCountH_reg == H_TOTAL - 1) begin
                oCountH_reg <= 0;
                if (oCountV_reg == V_TOTAL - 1) begin
                    oCountV_reg <= 0;
                end else begin
                    oCountV_reg <= oCountV_reg + 1;
                end
            end else begin
                oCountH_reg <= oCountH_reg + 1;
            end
        end
    end

    // Generate sync signals (active low)
    assign oHS = !(oCountH_reg >= H_DISPLAY_WIDTH + H_FRONT_PORCH &&
                  oCountH_reg < H_DISPLAY_WIDTH + H_FRONT_PORCH + H_SYNC_WIDTH);

    assign oVS = !(oCountV_reg >= V_DISPLAY_WIDTH + V_FRONT_PORCH &&
                  oCountV_reg < V_DISPLAY_WIDTH + V_FRONT_PORCH + V_SYNC_WIDTH);

    assign oCountH = oCountH_reg;
    assign oCountV = oCountV_reg;

endmodule

module testbench;
    reg clk;
    reg clear;
    wire hsync;
    wire vsync;
    wire [9:0] count_h;
    wire [9:0] count_v;

    VGA_timings #(
        .H_DISPLAY_WIDTH(640),
        .H_FRONT_PORCH(16),
        .H_SYNC_WIDTH(96),
        .H_BACK_PORCH(48),
        .V_DISPLAY_WIDTH(480),
        .V_FRONT_PORCH(10),
        .V_SYNC_WIDTH(2),
        .V_BACK_PORCH(33)
    ) dut (
        .iClk(clk),
        .iClear(clear),
        .oHS(hsync),
        .oVS(vsync),
        .oCountH(count_h),
        .oCountV(count_v)
    );

    initial begin
        clk = 0;
        clear = 0;
        // Wait a bit then apply clear for a few cycles
        #10;
        clear = 1;
        repeat (3) @(posedge clk);
        clear = 0;
        // Now run for a few frames
        repeat (5000) @(posedge clk);
        $finish;
    end

    always #5 clk = ~clk;

endmodule
