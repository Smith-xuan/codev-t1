// Verilog code that resulted in empty output
// Saved at: 2026-01-14T17:40:38.539026
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

module test1(
    input A,
    input B,
    input C,
    input G1,
    input G2A,
    input G3A,
    output Y0_L,
    output Y1_L,
    output Y2_L,
    output Y3_L,
    output Y4_L,
    output Y5_L,
    output Y6_L,
    output Y7_L,
    output G
);
    wire enable = G1 & (~G2A) & (~G3A);
    assign G = enable;
    // Compute address terms
    wire addr0 = ~C & ~B & ~A;
    wire addr1 = ~C & ~B & A;
    wire addr2 = ~C & B & ~A;
    wire addr3 = ~C & B & A;
    wire addr4 = C & ~B & ~A;
    wire addr5 = C & ~B & A;
    wire addr6 = C & B & ~A;
    wire addr7 = C & B & A;
    // Outputs using NAND gates
    nand(Y0_L, enable, addr0);
    nand(Y1_L, enable, addr1);
    nand(Y2_L, enable, addr2);
    nand(Y3_L, enable, addr3);
    nand(Y4_L, enable, addr4);
    nand(Y5_L, enable, addr5);
    nand(Y6_L, enable, addr6);
    nand(Y7_L, enable, addr7);
endmodule

module testbench;
    reg A, B, C, G1, G2A, G3A;
    wire Y0_L, Y1_L, Y2_L, Y3_L, Y4_L, Y5_L, Y6_L, Y7_L, G;
    test1 dut (.*);
    
    integer i;
    reg [7:0] expected_outputs;
    reg expected_enable;
    reg [2:0] addr;
    
    initial begin
        // iterate over all possible input combinations (6 inputs => 64)
        for (i = 0; i < 64; i = i + 1) begin
            {G1, G2A, G3A, C, B, A} = i[5:0]; // map bits as described
            @(0); // wait for combinational propagation
            
            // compute expected values
            expected_enable = G1 & (~G2A) & (~G3A);
            addr = {C, B, A};
            expected_outputs = ~(expected_enable << addr);
            
            // compare each output
            if (Y0_L !== expected_outputs[0]) begin
                $display("ERROR at i=%0d (G1=%b, G2A=%b, G3A=%b, A=%b, B=%b, C=%b): Y0_L = %b, expected %b",
                         i, G1, G2A, G3A, A, B, C, Y0_L, expected_outputs[0]);
                $finish;
            end
            if (Y1_L !== expected_outputs[1]) begin
                $display("ERROR at i=%0d: Y1_L = %b, expected %b",
                         i, Y1_L, expected_outputs[1]);
                $finish;
            end
            if (Y2_L !== expected_outputs[2]) begin
                $display("ERROR at i=%0d: Y2_L = %b, expected %b",
                         i, Y2_L, expected_outputs[2]);
                $finish;
            end
            if (Y3_L !== expected_outputs[3]) begin
                $display("ERROR at i=%0d: Y3_L = %b, expected %b",
                         i, Y3_L, expected_outputs[3]);
                $finish;
            end
            if (Y4_L !== expected_outputs[4]) begin
                $display("ERROR at i=%0d: Y4_L = %b, expected %b",
                         i, Y4_L, expected_outputs[4]);
                $finish;
            end
            if (Y5_L !== expected_outputs[5]) begin
                $display("ERROR at i=%0d: Y5_L = %b, expected %b",
                         i, Y5_L, expected_outputs[5]);
                $finish;
            end
            if (Y6_L !== expected_outputs[6]) begin
                $display("ERROR at i=%0d: Y6_L = %b, expected %b",
                         i, Y6_L, expected_outputs[6]);
                $finish;
            end
            if (Y7_L !== expected_outputs[7]) begin
                $display("ERROR at i=%0d: Y7_L = %b, expected %b",
                         i, Y7_L, expected_outputs[7]);
                $finish;
            end
            if (G !== expected_enable) begin
                $display("ERROR at i=%0d: G = %b, expected %b",
                         i, G, expected_enable);
                $finish;
            end
        end
        $display("All tests passed!");
        $finish;
    end
endmodule
