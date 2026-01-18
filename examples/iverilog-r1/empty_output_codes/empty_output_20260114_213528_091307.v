// Verilog code that resulted in empty output
// Saved at: 2026-01-14T21:35:28.091335
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
    output [9:0] o_pixel_x,
    output [9:0] o_pixel_y,
    output o_hsync,
    output o_vsync,
    output o_video_on,
    output o_p_tick
);

    reg [9:0] h_cnt; // horizontal counter (0-799)
    reg [9:0] v_cnt; // vertical counter (0-524)
    reg p_tick_reg;

    always @(posedge i_clk) begin
        if (i_reset) begin
            h_cnt <= 0;
            v_cnt <= 0;
            p_tick_reg <= 0;
        end else begin
            p_tick_reg <= ~p_tick_reg;
            if (p_tick_reg) begin
                if (h_cnt == 10'd799) begin
                    h_cnt <= 0;
                    if (v_cnt == 10'd524) begin
                        v_cnt <= 0;
                    end else begin
                        v_cnt <= v_cnt + 1;
                    end
                end else begin
                    h_cnt <= h_cnt + 1;
                end
            end
        end
    end

    // Horizontal sync: active low during sync pulse (656 to 751)
    assign o_hsync = ~( (h_cnt >= 656) && (h_cnt < 752) );

    // Vertical sync: active low during sync pulse (490 to 491)
    assign o_vsync = ~( (v_cnt >= 490) && (v_cnt < 492) );

    // Video on when in display area (0-639 horizontal, 0-479 vertical)
    assign o_video_on = (h_cnt < 640) && (v_cnt < 480);

    // Pixel coordinates: only valid when video_on, output 0 otherwise
    assign o_pixel_x = (h_cnt < 640) ? h_cnt : 10'd0;
    assign o_pixel_y = (v_cnt < 480) ? v_cnt : 10'd0;

    // Pixel tick: 25 MHz square wave (50% duty cycle)
    assign o_p_tick = p_tick_reg;

endmodule

module testbench;
    reg clk;
    reg reset;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire hsync;
    wire vsync;
    wire video_on;
    wire p_tick;

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
        #5000000; // simulate about 500 us? Let's simulate a few frames.
        $finish;
    end

    always #10 clk = ~clk; // 50 MHz period = 20 ns -> half period 10 ns.

endmodule
