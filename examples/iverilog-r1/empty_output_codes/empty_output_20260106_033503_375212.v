// Verilog code that resulted in empty output
// Saved at: 2026-01-06T03:35:03.375245
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

// FullAdder module
module FullAdder(
  input a,
  input b,
  input cin,
  output sum,
  output cout
);
  assign sum = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

// 16-bit ripple-carry adder using FullAdder instances
module Adder16(
  input [15:0] a,
  input [15:0] b,
  output [15:0] sum,
  output cout
);
  wire [14:0] carry;
  FullAdder fa0( .a(a[0]), .b(b[0]), .cin(1'b0), .sum(sum[0]), .cout(carry[0]));
  FullAdder fa1( .a(a[1]), .b(b[1]), .cin(carry[0]), .sum(sum[1]), .cout(carry[1]));
  FullAdder fa2( .a(a[2]), .b(b[2]), .cin(carry[1]), .sum(sum[2]), .cout(carry[2]));
  FullAdder fa3( .a(a[3]), .b(b[3]), .cin(carry[2]), .sum(sum[3]), .cout(carry[3]));
  FullAdder fa4( .a(a[4]), .b(b[4]), .cin(carry[3]), .sum(sum[4]), .cout(carry[4]));
  FullAdder fa5( .a(a[5]), .b(b[5]), .cin(carry[4]), .sum(sum[5]), .cout(carry[5]));
  FullAdder fa6( .a(a[6]), .b(b[6]), .cin(carry[5]), .sum(sum[6]), .cout(carry[6]));
  FullAdder fa7( .a(a[7]), .b(b[7]), .cin(carry[6]), .sum(sum[7]), .cout(carry[7]));
  FullAdder fa8( .a(a[8]), .b(b[8]), .cin(carry[7]), .sum(sum[8]), .cout(carry[8]));
  FullAdder fa9( .a(a[9]), .b(b[9]), .cin(carry[8]), .sum(sum[9]), .cout(carry[9]));
  FullAdder fa10( .a(a[10]), .b(b[10]), .cin(carry[9]), .sum(sum[10]), .cout(carry[10]));
  FullAdder fa11( .a(a[11]), .b(b[11]), .cin(carry[10]), .sum(sum[11]), .cout(carry[11]));
  FullAdder fa12( .a(a[12]), .b(b[12]), .cin(carry[11]), .sum(sum[12]), .cout(carry[12]));
  FullAdder fa13( .a(a[13]), .b(b[13]), .cin(carry[12]), .sum(sum[13]), .cout(carry[13]));
  FullAdder fa14( .a(a[14]), .b(b[14]), .cin(carry[13]), .sum(sum[14]), .cout(carry[14]));
  FullAdder fa15( .a(a[15]), .b(b[15]), .cin(carry[14]), .sum(sum[15]), .cout(cout));
endmodule

// Multiplier module using full adders
module MULT(
  input [7:0] MULTIPLICAND,
  input [7:0] MULTIPLIER,
  output [7:0] OUT
);
  wire [15:0] product;
  wire [15:0] pp [0:7];
  
  // Generate partial products and zero-extend to 16 bits
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_pp
      wire [7:0] partial;
      assign partial = MULTIPLICAND & {8{MULTIPLIER[i]}};
      assign pp[i] = {8'b0, partial} << i;
    end
  endgenerate
  
  // First level: add pairs of partial products (8 -> 4)
  wire [15:0] temp0, temp1, temp2, temp3;
  Adder16 add01(.a(pp[0]), .b(pp[1]), .sum(temp0), .cout());
  Adder16 add23(.a(pp[2]), .b(pp[3]), .sum(temp1), .cout());
  Adder16 add45(.a(pp[4]), .b(pp[5]), .sum(temp2), .cout());
  Adder16 add67(.a(pp[6]), .b(pp[7]), .sum(temp3), .cout());
  
  // Second level: combine pairs (4 -> 2)
  wire [15:0] temp4, temp5;
  Adder16 add0123(.a(temp0), .b(temp1), .sum(temp4), .cout());
  Adder16 add4567(.a(temp2), .b(temp3), .sum(temp5), .cout());
  
  // Third level: final addition (2 -> 1)
  Adder16 add_final(.a(temp4), .b(temp5), .sum(product), .cout());
  
  // Temporary bus RESULT (as specified)
  wire [15:0] RESULT;
  assign RESULT = product;
  
  // Output with delay of 3 time units
  assign #3 OUT = RESULT[7:0];
endmodule

// Additional random testbench to verify more cases
module testbench;
  reg [7:0] MULTIPLICAND, MULTIPLIER;
  wire [7:0] OUT;
  
  MULT dut (.MULTIPLICAND(MULTIPLICAND), .MULTIPLIER(MULTIPLIER), .OUT(OUT));
  
  integer i;
  integer errors;
  reg [15:0] expected;
  
  initial begin
    errors = 0;
    
    // Random test with a few hundred combinations
    for (i = 0; i < 300; i = i + 1) begin
      MULTIPLICAND = $random;
      MULTIPLIER = $random;
      #10; // wait for delay
      expected = MULTIPLICAND * MULTIPLIER;
      if (OUT !== expected[7:0]) begin
        $display("ERROR: %d * %d = %d, expected lower byte %d", MULTIPLICAND, MULTIPLIER, expected, expected[7:0]);
        errors = errors + 1;
      end
    end
    
    // Test signed interpretation (optional) - treat as unsigned already
    // Keep it simple.
    
    if (errors == 0) begin
      $display("\nAll random tests PASSED");
    end else begin
      $display("\nFAILED: %d errors in random tests", errors);
    end
    
    // Also test all-zero and all-one cases
    test_case(8'd0, 8'd0);
    test_case(8'd255, 8'd255);
    test_case(8'd128, 8'd128);
    test_case(8'd255, 8'd0);
    test_case(8'd0, 8'd255);
    test_case(8'd1, 8'd255);
    test_case(8'd255, 8'd1);
    test_case(8'd123, 8'd45);
  end
    
  task test_case;
    input [7:0] a, b;
    begin
      MULTIPLICAND = a;
      MULTIPLIER = b;
      #10;
      expected = a * b;
      if (OUT !== expected[7:0]) begin
        $display("ERROR: %d * %d = %d, expected lower byte %d", a, b, expected, expected[7:0]);
        errors = errors + 1;
      end
    end
  endtask
    
  initial $finish;
endmodule
