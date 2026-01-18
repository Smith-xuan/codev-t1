// Verilog code that resulted in empty output
// Saved at: 2026-01-14T11:11:35.318982
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

module top (
    input x0, x1, x2, x3, x4, x5, x6, x7, x8, x9,
    input x10, x11, x12, x13, x14, x15, x16, x17, x18, x19,
    input x20, x21, x22, x23,
    output y0
);

wire n25, n26, n27, n28, n29, n30, n31, n32, n33, n34, n35, n36;

assign n25 = (~x1) & (~x2);
assign n26 = x13 & n25;
assign n27 = (~x6) & (~x8);
assign n28 = (~x9) & n27;
assign n29 = x0 & (~n28);
assign n30 = n29 ^ x3;
assign n31 = n30 ^ n29;
assign n32 = x7 & (~x9);
assign n33 = n32 ^ n29;
assign n34 = n31 & n33;
assign n35 = n34 ^ n29;
assign n36 = n26 & n35;
assign y0 = n36;

endmodule

module testbench;
    reg x0, x1, x2, x3, x4, x5, x6, x7, x8, x9;
    reg x10, x11, x12, x13, x14, x15, x16, x17, x18, x19;
    reg x20, x21, x22, x23;
    wire y0;
    
    top dut (
        .x0(x0), .x1(x1), .x2(x2), .x3(x3), .x4(x4), .x5(x5),
        .x6(x6), .x7(x7), .x8(x8), .x9(x9),
        .x10(x10), .x11(x11), .x12(x12), .x13(x13), .x14(x14),
        .x15(x15), .x16(x16), .x17(x17), .x18(x18), .x19(x19),
        .x20(x20), .x21(x21), .x22(x22), .x23(x23),
        .y0(y0)
    );
    
    // Reference function to compute expected y0
    function compute_expected;
        input x0, x1, x2, x3, x4, x5, x6, x7, x8, x9;
        input x10, x11, x12, x13, x14, x15, x16, x17, x18, x19;
        input x20, x21, x22, x23;
        reg n25, n26, n27, n28, n29, n30, n31, n32, n33, n34, n35, n36;
        begin
            n25 = (~x1) & (~x2);
            n26 = x13 & n25;
            n27 = (~x6) & (~x8);
            n28 = (~x9) & n27;
            n29 = x0 & (~n28);
            n30 = n29 ^ x3;
            n31 = n30 ^ n29;
            n32 = x7 & (~x9);
            n33 = n32 ^ n29;
            n34 = n31 & n33;
            n35 = n34 ^ n29;
            n36 = n26 & n35;
            compute_expected = n36;
        end
    endfunction
    
    reg [23:0] x_vec;
    integer i, errors;
    
    initial begin
        errors = 0;
        // Exhaustive test of the 9 relevant inputs, other inputs set to 0
        for (i = 0; i < 512; i = i + 1) begin
            // Set the 9 relevant bits: x0, x1, x2, x3, x6, x7, x8, x9, x13
            // i bits [8:0] correspond to x0..x2? Actually we need to map.
            // Let's assign bits as follows:
            // bit 0: x0
            // bit 1: x1
            // bit 2: x2
            // bit 3: x3
            // bit 4: x4 (not relevant) set to 0
            // bit 5: x5 not relevant
            // bit 6: x6
            // bit 7: x7
            // bit 8: x8
            // bit 9: x9
            // bit 10: x10 not relevant
            // ... up to bit 23: x23 not relevant.
            // So we'll set i bits to x0..x9? Let's define a mapping.
            // Let's use bits 0-8 for the relevant 9 inputs.
            {x0, x1, x2, x3, x4, x5, x6, x7, x8, x9} = i[8:0];
            // Other inputs set to 0
            x10 = 0; x11 = 0; x12 = 0; x13 = i[9]; // Wait i only 9 bits. x13 is separate.
            // Actually x13 should be bit 9 of i? Let's adjust.
            // We'll set i as combination of 9 bits: x0..x2, x3, x6, x7, x8, x9, x13.
            // Let's create a vector of 9 bits: [x0, x1, x2, x3, x6, x7, x8, x9, x13]
            // We'll manually map.
            // Instead, we can compute each individually.
            // Let's do a simpler approach: generate all 512 combinations of x0..x9 excluding x4,x5,x10,x11,x12,x14..x23.
            // Since we have only 9 relevant inputs, we can loop i from 0 to 511 and assign each of those 9 bits.
            // Let's create an array.
            // But easier: use a for loop with a 9-bit vector.
            // Let's define a wire [8:0] vec = i;
            // assign bits as:
            // vec[0] -> x0
            // vec[1] -> x1
            // vec[2] -> x2
            // vec[3] -> x3
            // vec[4] -> x6
            // vec[5] -> x7
            // vec[6] -> x8
            // vec[7] -> x9
            // vec[8] -> x13
            // The other inputs not in this list set to 0.
            // Let's implement.
        end
        // Since the previous test passed, we can just rely on random.
        // But let's do proper exhaustive.
    end
endmodule
