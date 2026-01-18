// Verilog code that resulted in empty output
// Saved at: 2026-01-14T13:59:28.919520
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

module vga_timing (
    input clk,
    input rst,
    output [10:0] vcount,
    output vsync,
    output vblnk,
    output [10:0] hcount,
    output hsync,
    output hblnk
);

    reg [10:0] hcount_reg;
    reg [10:0] vcount_reg;

    // Sequential logic for counters
    always @(posedge clk) begin
        if (rst) begin
            hcount_reg <= 11'd0;
            vcount_reg <= 11'd0;
        end else begin
            if (hcount_reg == 11'd1055) begin
                hcount_reg <= 11'd0;
                if (vcount_reg == 11'd627)
                    vcount_reg <= 11'd0;
                else
                    vcount_reg <= vcount_reg + 1'b1;
            end else begin
                hcount_reg <= hcount_reg + 1'b1;
            end
        end
    end

    // Output assignments
    assign hcount = hcount_reg;
    assign vcount = vcount_reg;

    // Generate sync signals
    // hsync active when hcount between 840 and 968 inclusive
    assign hsync = (hcount_reg >= 11'd840) && (hcount_reg <= 11'd968);
    // vsync active when vcount between 601 and 604 inclusive
    assign vsync = (vcount_reg >= 11'd601) && (vcount_reg <= 11'd604);
    // hblnk active when hcount between 800 and 1055 inclusive
    assign hblnk = (hcount_reg >= 11'd800) && (hcount_reg <= 11'd1055);
    // vblnk active when vcount between 600 and 627 inclusive
    assign vblnk = (vcount_reg >= 11'd600) && (vcount_reg <= 11'd627);

endmodule

// Testbench
module testbench;
    reg clk;
    reg rst;
    wire [10:0] vcount;
    wire vsync;
    wire vblnk;
    wire [10:0] hcount;
    wire hsync;
    wire hblnk;

    vga_timing dut (
        .clk(clk),
        .rst(rst),
        .vcount(vcount),
        .vsync(vsync),
        .vblnk(vblnk),
        .hcount(hcount),
        .hsync(hsync),
        .hblnk(hblnk)
    );

    // Clock generation: 40 MHz => period 25 ns
    initial begin
        clk = 0;
        forever #12.5 clk = ~clk; // 25 ns period => 12.5 high, 12.5 low
    end

    // Stimulus
    initial begin
        rst = 1;
        #100;
        rst = 0;
        // Simulate a few thousand cycles to see behavior
        #200000; // 200 us = 8000 pixels? Actually 200,000 ns = 200 us = 8000 clock cycles at 40 MHz? Wait: 40 MHz period 25 ns, so 200,000 ns = 8000 cycles.
        $finish;
    end

    // Monitor some signals
    integer frame_count = 0;
    always @(posedge clk) begin
        if (!rst) begin
            if (hcount == 1055 && vcount == 627) begin
                frame_count = frame_count + 1;
                $display("Frame %0d completed at time %t", frame_count, $time);
                if (frame_count == 2) begin
                    $display("Two frames simulated.");
                    $finish;
                end
            end
        end
    end

endmodule
