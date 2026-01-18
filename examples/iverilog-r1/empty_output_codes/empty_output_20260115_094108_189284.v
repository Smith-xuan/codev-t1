// Verilog code that resulted in empty output
// Saved at: 2026-01-15T09:41:08.189307
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

    // Parameters for 640x480 @ 60Hz (25.175 MHz pixel clock approximated as 25 MHz)
    localparam H_DISP = 640;
    localparam H_FRONT = 16;
    localparam H_SYNC = 96;
    localparam H_BACK = 48;
    localparam H_TOTAL = H_DISP + H_FRONT + H_SYNC + H_BACK; // 800

    localparam V_DISP = 480;
    localparam V_FRONT = 10;
    localparam V_SYNC = 2;
    localparam V_BACK = 33;
    localparam V_TOTAL = V_DISP + V_FRONT + V_SYNC + V_BACK; // 525

    reg [9:0] h_counter; // horizontal counter (0 to 799)
    reg [9:0] v_counter; // vertical counter (0 to 524)

    // Toggle for 25 MHz pixel tick
    reg toggle;
    reg toggle_prev;

    always @(posedge i_clk) begin
        if (i_reset) begin
            toggle <= 1'b0;
            toggle_prev <= 1'b0;
        end else begin
            toggle <= ~toggle;
            toggle_prev <= toggle;
        end
    end

    assign o_p_tick = toggle && !toggle_prev; // rising edge of toggle (25 MHz)

    always @(posedge i_clk) begin
        if (i_reset) begin
            h_counter <= 0;
            v_counter <= 0;
        end else begin
            // Update horizontal counter on pixel tick
            if (o_p_tick) begin
                if (h_counter == H_TOTAL - 1) begin
                    h_counter <= 0;
                    // At the end of line, increment vertical counter
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
    end

    // Output pixel coordinates
    always @(*) begin
        o_pixel_x = h_counter;
        o_pixel_y = v_counter;
    end

    // Video on signal: active when within visible area
    assign o_video_on = (h_counter < H_DISP) && (v_counter < V_DISP);

    // Horizontal sync: active low during sync pulse
    assign o_hsync = ~((h_counter >= (H_DISP + H_FRONT)) && (h_counter < (H_DISP + H_FRONT + H_SYNC)));

    // Vertical sync: active low during sync pulse
    assign o_vsync = ~((v_counter >= (V_DISP + V_FRONT)) && (v_counter < (V_DISP + V_FRONT + V_SYNC)));

endmodule

module testbench;
    reg i_clk;
    reg i_reset;
    wire [9:0] o_pixel_x;
    wire [9:0] o_pixel_y;
    wire o_hsync;
    wire o_vsync;
    wire o_video_on;
    wire o_p_tick;

    vga_sync dut (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .o_pixel_x(o_pixel_x),
        .o_pixel_y(o_pixel_y),
        .o_hsync(o_hsync),
        .o_vsync(o_vsync),
        .o_video_on(o_video_on),
        .o_p_tick(o_p_tick)
    );

    // Clock generation
    initial begin
        i_clk = 0;
        forever #10 i_clk = ~i_clk; // 50 MHz period = 20 ns => half period 10 ns
    end

    // Reset and simulation control
    initial begin
        i_reset = 1;
        #100;
        i_reset = 0;
        // Let's run for a few lines
        #200000; // 200 us
        $finish;
    end

    // Check some conditions
    integer h_count, v_count;
    always @(posedge i_clk) begin
        h_count = dut.h_counter;
        v_count = dut.v_counter;
        // Check that p_tick occurs at half rate
        if ($time > 100) begin
            // Count p_tick pulses
        end
    end
endmodule
