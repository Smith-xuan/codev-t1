// Verilog code that resulted in empty output
// Saved at: 2026-01-14T17:39:50.203753
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

module NVC293 (
    input clk,
    input [5:0] din,
    output [5:0] dout,
    input [1:0] sel,
    input delay
);

reg [5:0] stage0, stage1, stage2;
reg [5:0] dout_reg;
wire [5:0] mux_out;

assign mux_out = (sel == 2'b00) ? din :
                 (sel == 2'b01) ? stage0 :
                 (sel == 2'b10) ? stage1 : stage2;

always @(posedge clk) begin
    stage0 <= din;
    stage1 <= stage0;
    stage2 <= stage1;
    dout_reg <= mux_out;
end

assign dout = delay ? dout_reg : mux_out;

endmodule

module testbench;
    reg clk;
    reg [5:0] din;
    reg [1:0] sel;
    reg delay;
    wire [5:0] dout;
    
    NVC293 dut (
        .clk(clk),
        .din(din),
        .dout(dout),
        .sel(sel),
        .delay(delay)
    );
    
    // Reference model
    reg [5:0] ref_stage0, ref_stage1, ref_stage2, ref_dout_reg;
    wire [5:0] ref_mux_out, ref_dout;
    
    assign ref_mux_out = (sel == 2'b00) ? din :
                        (sel == 2'b01) ? ref_stage0 :
                        (sel == 2'b10) ? ref_stage1 : ref_stage2;
    assign ref_dout = delay ? ref_dout_reg : ref_mux_out;
    
    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Stimulus: generate random inputs at negedge
    integer i, seed;
    initial begin
        seed = 12345;
        din = 0;
        sel = 0;
        delay = 0;
        #1;
        for (i = 0; i < 100; i = i + 1) begin
            @(negedge clk);
            din = $urandom(seed) & 6'h3F;
            sel = ($urandom(seed) & 3) + 1; // change randomly
            delay = $urandom(seed) & 1;
        end
        #100 $finish;
    end
    
    // Checker at each posedge
    integer error_count;
    initial begin
        error_count = 0;
        forever begin
            @(posedge clk);
            #1; // wait for signals to settle
            if (dout !== ref_dout) begin
                $display("ERROR at time %0t: sel=%b, delay=%b, din=%h", $time, sel, delay, din);
                $display("  DUT dout = %h, expected dout = %h", dout, ref_dout);
                $display("  ref_stage0=%h, ref_stage1=%h, ref_stage2=%h, ref_dout_reg=%h, ref_mux_out=%h",
                         ref_stage0, ref_stage1, ref_stage2, ref_dout_reg, ref_mux_out);
                error_count = error_count + 1;
            end
        end
    end
    
    // Update reference registers at each posedge (same as DUT)
    always @(posedge clk) begin
        ref_stage0 <= din;
        ref_stage1 <= ref_stage0;
        ref_stage2 <= ref_stage1;
        ref_dout_reg <= ref_mux_out;
    end
    
endmodule
