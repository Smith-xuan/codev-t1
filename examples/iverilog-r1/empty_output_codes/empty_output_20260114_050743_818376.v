// Verilog code that resulted in empty output
// Saved at: 2026-01-14T05:07:43.818418
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

module vga_sync (
    input i_clk,
    input i_reset,
    output reg [9:0] o_pixel_x,
    output reg [9:0] o_pixel_y,
    output o_hsync,
    output o_vsync,
    output o_video_on,
    output o_p_tick
);

// Timing constants for 640x480 VGA @ 60Hz (25.175 MHz pixel clock approximated as 25 MHz)
parameter H_DISPLAY = 640;
parameter H_FP = 16;
parameter H_SYNC = 96;
parameter H_BP = 48;
parameter H_TOTAL = H_DISPLAY + H_FP + H_SYNC + H_BP;  // 800

parameter V_DISPLAY = 480;
parameter V_FP = 10;
parameter V_SYNC = 2;
parameter V_BP = 33;
parameter V_TOTAL = V_DISPLAY + V_FP + V_SYNC + V_BP;  // 525

// Horizontal and vertical counters
reg [9:0] h_counter;
reg [9:0] v_counter;
// Div2 toggle for 25 MHz pixel tick
reg div2;
reg div2_dly;
wire pixel_en;

// Pixel enable pulse on rising edge of div2
assign pixel_en = div2 & ~div2_dly;

// Update div2 and its delayed version
always @(posedge i_clk) begin
    if (i_reset) begin
        div2 <= 1'b0;
        div2_dly <= 1'b0;
    end else begin
        div2_dly <= div2;
        div2 <= ~div2;
    end
end

// Horizontal and vertical counters
always @(posedge i_clk) begin
    if (i_reset) begin
        h_counter <= 0;
        v_counter <= 0;
    end else if (pixel_en) begin
        // Increment horizontal counter
        if (h_counter == H_TOTAL - 1) begin
            h_counter <= 0;
            // Increment vertical counter when horizontal wraps
            if (v_counter == V_TOTAL - 1) begin
                v_counter <= 0;
            end else begin
                v_counter <= v_counter + 1;
            end
        end else begin
            h_counter <= h_counter + 1;
        end
    end
end

// Output registers (optional but good practice)
reg hsync_reg, vsync_reg, video_on_reg;

// Compute sync and video_on signals combinationally
wire h_sync_active = (h_counter >= H_DISPLAY);
wire v_sync_active = (v_counter >= V_DISPLAY);
wire video_on = (h_counter < H_DISPLAY) && (v_counter < V_DISPLAY);

// Register outputs
always @(posedge i_clk) begin
    if (i_reset) begin
        hsync_reg <= 1'b1;  // inactive high (sync is active low)
        vsync_reg <= 1'b1;
        video_on_reg <= 1'b0;
    end else begin
        hsync_reg <= ~h_sync_active;
        vsync_reg <= ~v_sync_active;
        video_on_reg <= video_on;
    end
end

// Assign outputs
assign o_hsync = hsync_reg;
assign o_vsync = vsync_reg;
assign o_video_on = video_on_reg;
assign o_p_tick = div2;

// Pixel coordinates (combinational)
always @(*) begin
    if (h_counter >= H_DISPLAY) begin
        o_pixel_x = h_counter - H_DISPLAY;
    end else begin
        o_pixel_x = h_counter;
    end
    if (v_counter >= V_DISPLAY) begin
        o_pixel_y = v_counter - V_DISPLAY;
    end else begin
        o_pixel_y = v_counter;
    end
end

endmodule

module testbench;
reg clk;
reg reset;
wire [9:0] pixel_x, pixel_y;
wire hsync, vsync, video_on, p_tick;

vga_sync dut (
    .i_clk(clk),
    .i_reset(reset),
    .o_pixel_x(pixel_x),
    .o_pixel_y(pixel_y),
    .o_hsync(hsync),
    .o_vsync(vsync),
    .o_video_on(video_on),
    .o_p_tick(p_tick)
);

initial begin
    clk = 0;
    reset = 1;
    #100;
    reset = 0;
    #2000000; // simulate for a while
    $finish;
end

always #10 clk = ~clk; // 50 MHz period 20 ns

endmodule
