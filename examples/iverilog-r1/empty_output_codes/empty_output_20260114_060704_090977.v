// Verilog code that resulted in empty output
// Saved at: 2026-01-14T06:07:04.091011
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

module MUX32(
    input I0, I1, I2, I3, I4, I5, I6, I7, I8, I9,
    input I10, I11, I12, I13, I14, I15,
    input I16, I17, I18, I19, I20, I21, I22, I23,
    input I24, I25, I26, I27, I28, I29, I30, I31,
    input S4, S3, S2, S1, S0,
    output O
);
    wire [31:0] mux_in = {I31, I30, I29, I28, I27, I26, I25, I24,
                          I23, I22, I21, I20, I19, I18, I17, I16,
                          I15, I14, I13, I12, I11, I10, I9, I8,
                          I7, I6, I5, I4, I3, I2, I1, I0};
    wire [4:0] sel = {S4, S3, S2, S1, S0};
    assign O = mux_in[sel];
endmodule

module testbench;
    // Inputs
    reg I0, I1, I2, I3, I4, I5, I6, I7, I8, I9;
    reg I10, I11, I12, I13, I14, I15;
    reg I16, I17, I18, I19, I20, I21, I22, I23;
    reg I24, I25, I26, I27, I28, I29, I30, I31;
    reg S4, S3, S2, S1, S0;
    // Output
    wire O;
    
    // Instantiate the DUT
    MUX32 dut (
        .I0(I0), .I1(I1), .I2(I2), .I3(I3), .I4(I4), .I5(I5), .I6(I6), .I7(I7), .I8(I8), .I9(I9),
        .I10(I10), .I11(I11), .I12(I12), .I13(I13), .I14(I14), .I15(I15),
        .I16(I16), .I17(I17), .I18(I18), .I19(I19), .I20(I20), .I21(I21), .I22(I22), .I23(I23),
        .I24(I24), .I25(I25), .I26(I26), .I27(I27), .I28(I28), .I29(I29), .I30(I30), .I31(I31),
        .S4(S4), .S3(S3), .S2(S2), .S1(S1), .S0(S0),
        .O(O)
    );
    
    integer i;
    integer errors;
    reg [4:0] expected_sel;
    wire [31:0] input_vector;
    
    initial begin
        errors = 0;
        
        // Assign random values to all inputs, but we also need to test each selection.
        // We'll set each input to a unique pattern: I0 = 0, I1 = 1, I2 = 2, ... I31 = 31.
        // However each input is a single bit; we can't assign values >1. Let's assign each input to its index mod 2? 
        // Better: assign each input to 0 for even index, 1 for odd index.
        // That will make each input carry a different bit pattern.
        // We'll assign I0=1'b0, I1=1'b1, I2=1'b0, I3=1'b1, etc.
        // But we need to test that O matches the input corresponding to sel.
        // Let's use a consistent pattern: set all inputs to 0 except the one we intend to select.
        // So we will test each select value individually.
        
        // First, set all inputs to 0.
        I0 = 0; I1 = 0; I2 = 0; I3 = 0; I4 = 0; I5 = 0; I6 = 0; I7 = 0; I8 = 0; I9 = 0;
        I10 = 0; I11 = 0; I12 = 0; I13 = 0; I14 = 0; I15 = 0;
        I16 = 0; I17 = 0; I18 = 0; I19 = 0; I20 = 0; I21 = 0; I22 = 0; I23 = 0;
        I24 = 0; I25 = 0; I26 = 0; I27 = 0; I28 = 0; I29 = 0; I30 = 0; I31 = 0;
        
        // Test each select value from 0 to 31
        for (i = 0; i < 32; i = i + 1) begin
            // Set only the input corresponding to i to 1
            case (i)
                0: begin I0 = 1'bx; end // Wait: we need to set exactly the correct input to 1. Use array.
                // Since we can't have a dynamic case on bits, we'll use a loop over indices.
                // Actually we can assign each input separately in a loop? Not easy.
                // Let's use a different approach: create a 32-bit vector of inputs and assign bits.
            endcase
        end
    end
endmodule
