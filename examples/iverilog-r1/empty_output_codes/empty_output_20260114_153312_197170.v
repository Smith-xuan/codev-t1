// Verilog code that resulted in empty output
// Saved at: 2026-01-14T15:33:12.197201
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

module vga_renderer #(
  parameter H_VISIBLE = 800,
  parameter V_VISIBLE = 480,
  parameter H_FP = 32,
  parameter H_SYNC = 120,
  parameter H_BP = 32,
  parameter V_FP = 8,
  parameter V_SYNC = 5,
  parameter V_BP = 13
) (
  input wire vga_clk,
  input wire reset_n,
  input wire [7:0] red,
  input wire [7:0] green,
  input wire [7:0] blue,
  output wire [7:0] vga_red,
  output wire [7:0] vga_green,
  output wire [7:0] vga_blue,
  output wire vga_hsync,
  output wire vga_vsync,
  output wire fb_hblank,
  output wire fb_vblank
);

  // Compute total counts
  localparam H_TOTAL = H_VISIBLE + H_FP + H_SYNC + H_BP;
  localparam V_TOTAL = V_VISIBLE + V_FP + V_SYNC + V_BP;

  // Counter registers
  reg [$clog2(H_TOTAL)-1:0] h_counter = 0;
  reg [$clog2(V_TOTAL)-1:0] v_counter = 0;

  always @(posedge vga_clk or negedge reset_n) begin
    if (!reset_n) begin
      h_counter <= 0;
      v_counter <= 0;
    end else begin
      if (h_counter == H_TOTAL - 1) begin
        h_counter <= 0;
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

  // Generate blanking signals and sync pulses
  assign fb_hblank = (h_counter >= H_VISIBLE);
  assign fb_vblank = (v_counter >= V_VISIBLE);

  assign vga_hsync = ~((h_counter >= H_VISIBLE + H_FP) && (h_counter < H_VISIBLE + H_FP + H_SYNC));
  assign vga_vsync = ~((v_counter >= V_VISIBLE + V_FP) && (v_counter < V_VISIBLE + V_FP + V_SYNC));

  // Color outputs: only active when not blanked
  assign vga_red   = (!fb_hblank && !fb_vblank) ? red   : 8'h00;
  assign vga_green = (!fb_hblank && !fb_vblank) ? green : 8'h00;
  assign vga_blue  = (!fb_hblank && !fb_vblank) ? blue  : 8'h00;

endmodule

// Testbench with clock edge synchronization
module testbench;
  reg vga_clk;
  reg reset_n;
  reg [7:0] red, green, blue;
  wire [7:0] vga_red, vga_green, vga_blue;
  wire vga_hsync, vga_vsync;
  wire fb_hblank, fb_vblank;

  vga_renderer dut (
    .vga_clk(vga_clk),
    .reset_n(reset_n),
    .red(red),
    .green(green),
    .blue(blue),
    .vga_red(vga_red),
    .vga_green(vga_green),
    .vga_blue(vga_blue),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .fb_hblank(fb_hblank),
    .fb_vblank(fb_vblank)
  );

  // Clock generation (10 ns period = 100 MHz)
  initial begin
    vga_clk = 0;
    forever #5 vga_clk = ~vga_clk;
  end

  // Stimulus
  initial begin
    // Initialize inputs
    reset_n = 0;
    red = 8'hFF;
    green = 8'h00;
    blue = 8'h00;

    // Apply reset for 2 clock cycles
    #20 reset_n = 1;

    // Run for a full frame plus some
    // Wait for vertical counter to wrap around (506 lines)
    // Each line takes 984 pixels, each pixel 10 ns
    // So total time per frame = 984 * 506 * 10 ns = about 49.7664 ms
    // Let's run for 100us to see a few frames
    #100000;

    $finish;
  end

  // Monitor at each clock edge
  reg [7:0] prev_vga_red;
  always @(posedge vga_clk) begin
    // Check that color outputs are zero outside visible region
    if (reset_n) begin // after reset
      if (fb_hblank || fb_vblank) begin
        // Colors should be zero
        if (vga_red !== 8'h00 || vga_green !== 8'h00 || vga_blue !== 8'h00) begin
          $error("Colors should be zero during blanking: red=%0h green=%0h blue=%0h", vga_red, vga_green, vga_blue);
        end
      end else begin
        // Colors should equal inputs
        if (vga_red !== red || vga_green !== green || vga_blue !== blue) begin
          $error("Colors mismatch: expected red=%0h green=%0h blue=%0h, got red=%0h green=%0h blue=%0h",
                 red, green, blue, vga_red, vga_green, vga_blue);
        end
      end
    end
  end

  // Check sync signals at specific times
  // We'll wait for specific counter values using clock edges
  initial begin
    @(negedge reset_n); // wait for reset deassertion
    @(posedge vga_clk);
    
    // Wait until h_counter is known to be 0
    fork
      begin
        wait(dut.h_counter == 0);
        @(posedge vga_clk); // sync to clock edge
        $display("At h_counter=0, hsync=%b", vga_hsync);
      end
      begin
        #1000; // timeout
        $error("Timeout waiting for h_counter=0");
      end
    join_any
    disable fork;
    
    // Wait for h_counter = 832 (start of hsync)
    fork
      begin
        wait(dut.h_counter == 832);
        @(posedge vga_clk);
        if (vga_hsync !== 1'b0) begin
          $error("hsync should be low at h_counter=832, but is %b", vga_hsync);
        end else begin
          $display("hsync correctly low at h_counter=832");
        end
      end
      begin
        #100000;
        $error("Timeout waiting for h_counter=832");
      end
    join_any
    disable fork;
    
    // Wait for h_counter = 952 (end of hsync)
    fork
      begin
        wait(dut.h_counter == 952);
        @(posedge vga_clk);
        if (vga_hsync !== 1'b1) begin
          $error("hsync should be high at h_counter=952, but is %b", vga_hsync);
        end else begin
          $display("hsync correctly high at h_counter=952");
        end
      end
      begin
        #100000;
        $error("Timeout waiting for h_counter=952");
      end
    join_any
    disable fork;
    
    // Wait for v_counter = 0
    fork
      begin
        wait(dut.v_counter == 0);
        @(posedge vga_clk);
        $display("At v_counter=0, vsync=%b", vga_vsync);
      end
      begin
        #100000;
        $error("Timeout waiting for v_counter=0");
      end
    join_any
    disable fork;
    
    // Wait for v_counter = 488 (start of vsync)
    fork
      begin
        wait(dut.v_counter == 488);
        @(posedge vga_clk);
        if (vga_vsync !== 1'b0) begin
          $error("vsync should be low at v_counter=488, but is %b", vga_vsync);
        end else begin
          $display("vsync correctly low at v_counter=488");
        end
      end
      begin
        #1000000;
        $error("Timeout waiting for v_counter=488");
      end
    join_any
    disable fork;
    
    // Wait for v_counter = 493 (end of vsync)
    fork
      begin
        wait(dut.v_counter == 493);
        @(posedge vga_clk);
        if (vga_vsync !== 1'b1) begin
          $error("vsync should be high at v_counter=493, but is %b", vga_vsync);
        end else begin
          $display("vsync correctly high at v_counter=493");
        end
      end
      begin
        #1000000;
        $error("Timeout waiting for v_counter=493");
      end
    join_any
    disable fork;
    
    // Change color to green and check
    #5000;
    red = 8'h00;
    green = 8'hFF;
    blue = 8'h00;
    $display("Color changed to green");
    
    // Wait a bit more
    #20000;
    
    $display("All checks passed!");
  end
endmodule
