// Verilog code that resulted in empty output
// Saved at: 2026-01-14T16:28:32.406208
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

module divRelojVGA_toggle #(parameter VALUE = 5) (
  input clk_in,
  input reset,
  output clk_out
);
  localparam WIDTH = $clog2(VALUE);
  reg [WIDTH-1:0] counter;
  reg clk_out_reg;
  
  always @(posedge clk_in or posedge reset) begin
    if (reset) begin
      counter <= 0;
      clk_out_reg <= 0;
    end else begin
      if (counter == VALUE - 1) begin
        counter <= 0;
        clk_out_reg <= ~clk_out_reg;
      end else begin
        counter <= counter + 1;
      end
    end
  end
  
  assign clk_out = clk_out_reg;
endmodule

module divRelojVGA_msb #(parameter VALUE = 5) (
  input clk_in,
  input reset,
  output clk_out
);
  localparam WIDTH = $clog2(VALUE);
  reg [WIDTH-1:0] counter;
  
  always @(posedge clk_in or posedge reset) begin
    if (reset) begin
      counter <= 0;
    end else begin
      if (counter == VALUE - 1) begin
        counter <= 0;
      end else begin
        counter <= counter + 1;
      end
    end
  end
  
  assign clk_out = counter[WIDTH-1];
endmodule

module testbench;
  reg clk_in;
  reg reset;
  wire clk_out_toggle, clk_out_msb;
  
  divRelojVGA_toggle #(5) dut_toggle (
    .clk_in(clk_in),
    .reset(reset),
    .clk_out(clk_out_toggle)
  );
  
  divRelojVGA_msb #(5) dut_msb (
    .clk_in(clk_in),
    .reset(reset),
    .clk_out(clk_out_msb)
  );
  
  initial begin
    clk_in = 0;
    reset = 1;
    #10 reset = 0;
    // Run for many cycles
    #200 $finish;
  end
  
  always #5 clk_in = ~clk_in;
endmodule
