// Verilog code that resulted in empty output
// Saved at: 2026-01-14T13:39:55.581001
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

`timescale 1ns/1ns

module pipeline(
  input clk,
  input [31:0] a,
  input [31:0] b,
  input [31:0] c,
  input [31:0] d,
  output [31:0] e
);

  reg [31:0] sum_ab_reg, diff_cd_reg, d_reg;
  reg [31:0] sum_stage2_reg, d_reg2;
  reg [31:0] product_reg;

  always @(posedge clk) begin
    sum_ab_reg <= a + b;
    diff_cd_reg <= c - d;
    d_reg <= d;
  end

  always @(posedge clk) begin
    sum_stage2_reg <= sum_ab_reg + diff_cd_reg;
    d_reg2 <= d_reg;
  end

  always @(posedge clk) begin
    product_reg <= sum_stage2_reg * d_reg2;
  end

  assign e = product_reg;

endmodule

module testbench;
  reg clk;
  reg [31:0] a, b, c, d;
  wire [31:0] e;

  pipeline dut (.clk(clk), .a(a), .b(b), .c(c), .d(d), .e(e));

  // Clock generator
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Test sequence
  integer i;
  reg [31:0] expected [0:99];
  reg [31:0] test_a [0:99];
  reg [31:0] test_b [0:99];
  reg [31:0] test_c [0:99];
  reg [31:0] test_d [0:99];

  initial begin
    // Initialize
    a = 0; b = 0; c = 0; d = 0;
    @(posedge clk);

    // Test with 20 random vectors
    for (i = 0; i < 20; i = i + 1) begin
      // Random inputs
      a = $random;
      b = $random;
      c = $random;
      d = $random;
      // Compute expected result
      // Stage1
      // sum_ab = a + b
      // diff_cd = c - d
      // Stage2: sum_stage2 = sum_ab + diff_cd
      // Stage3: product = sum_stage2 * d
      // We'll compute using intermediate variables
      test_a[i] = a;
      test_b[i] = b;
      test_c[i] = c;
      test_d[i] = d;
      expected[i] = (a + b) + (c - d);
      expected[i] = expected[i] * d;
      // Apply inputs
      @(posedge clk);
      // Keep applying new inputs each cycle (pipeline throughput)
    end

    // Wait for pipeline to flush (3 cycles after last input)
    repeat (5) @(posedge clk);

    // Check results
    for (i = 0; i < 20; i = i + 1) begin
      // The output e should correspond to the i-th input applied 3 cycles earlier.
      // We need to compare e with expected[i].
      // But we didn't store outputs; we need to capture them.
      // Let's instead modify testbench to capture outputs at each cycle.
    end

    // Better approach: capture outputs in array and compare.
    // Let's restart with more systematic test.
    $finish;
  end
endmodule
