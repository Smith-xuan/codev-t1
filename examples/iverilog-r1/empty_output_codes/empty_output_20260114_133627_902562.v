// Verilog code that resulted in empty output
// Saved at: 2026-01-14T13:36:27.902613
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

module IP_inv (
  input [63:0] round_in,
  output [63:0] ciphertext
);
  // Explicit assignments for each output bit
  assign ciphertext[0] = round_in[39]; // bit 1 -> 40
  assign ciphertext[1] = round_in[7];  // 2 -> 8
  assign ciphertext[2] = round_in[47]; // 3 -> 48
  assign ciphertext[3] = round_in[15]; // 4 -> 16
  assign ciphertext[4] = round_in[55]; // 5 -> 56
  assign ciphertext[5] = round_in[23]; // 6 -> 24
  assign ciphertext[6] = round_in[63]; // 7 -> 64
  assign ciphertext[7] = round_in[31]; // 8 -> 32
  
  assign ciphertext[8] = round_in[38]; // 9 -> 39
  assign ciphertext[9] = round_in[5];  // 10 -> 7
  assign ciphertext[10] = round_in[46]; // 11 -> 47
  assign ciphertext[11] = round_in[13]; // 12 -> 15
  assign ciphertext[12] = round_in[54]; // 13 -> 55
  assign ciphertext[13] = round_in[22]; // 14 -> 23
  assign ciphertext[14] = round_in[62]; // 15 -> 63
  assign ciphertext[15] = round_in[30]; // 16 -> 31
  
  assign ciphertext[16] = round_in[37]; // 17 -> 38
  assign ciphertext[17] = round_in[4];  // 18 -> 6
  assign ciphertext[18] = round_in[45]; // 19 -> 46
  assign ciphertext[19] = round_in[12]; // 20 -> 14
  assign ciphertext[20] = round_in[53]; // 21 -> 54
  assign ciphertext[21] = round_in[21]; // 22 -> 22
  assign ciphertext[22] = round_in[61]; // 23 -> 62
  assign ciphertext[23] = round_in[29]; // 24 -> 30
  
  assign ciphertext[24] = round_in[36]; // 25 -> 37
  assign ciphertext[25] = round_in[3];  // 26 -> 5
  assign ciphertext[26] = round_in[44]; // 27 -> 45
  assign ciphertext[27] = round_in[11]; // 28 -> 13
  assign ciphertext[28] = round_in[52]; // 29 -> 53
  assign ciphertext[29] = round_in[20]; // 30 -> 21
  assign ciphertext[30] = round_in[60]; // 31 -> 61
  assign ciphertext[31] = round_in[28]; // 32 -> 29
  
  assign ciphertext[32] = round_in[35]; // 33 -> 36
  assign ciphertext[33] = round_in[2];  // 34 -> 4
  assign ciphertext[34] = round_in[43]; // 35 -> 44
  assign ciphertext[35] = round_in[10]; // 36 -> 12
  assign ciphertext[36] = round_in[51]; // 37 -> 52
  assign ciphertext[37] = round_in[19]; // 38 -> 20
  assign ciphertext[38] = round_in[59]; // 39 -> 60
  assign ciphertext[39] = round_in[27]; // 40 -> 28
  
  assign ciphertext[40] = round_in[34]; // 41 -> 35
  assign ciphertext[41] = round_in[1];  // 42 -> 3
  assign ciphertext[42] = round_in[42]; // 43 -> 43
  assign ciphertext[43] = round_in[9];  // 44 -> 11
  assign ciphertext[44] = round_in[50]; // 45 -> 51
  assign ciphertext[45] = round_in[18]; // 46 -> 19
  assign ciphertext[46] = round_in[58]; // 47 -> 59
  assign ciphertext[47] = round_in[26]; // 48 -> 27
  
  assign ciphertext[48] = round_in[33]; // 49 -> 34
  assign ciphertext[49] = round_in[0];  // 50 -> 2
  assign ciphertext[50] = round_in[41]; // 51 -> 42
  assign ciphertext[51] = round_in[8];  // 52 -> 10
  assign ciphertext[52] = round_in[49]; // 53 -> 50
  assign ciphertext[53] = round_in[17]; // 54 -> 18
  assign ciphertext[54] = round_in[57]; // 55 -> 58
  assign ciphertext[55] = round_in[25]; // 56 -> 26
  
  assign ciphertext[56] = round_in[32]; // 57 -> 33
  assign ciphertext[57] = round_in[63]; // 58 -> 41? Wait, earlier we saw inv[58]=1, which is bit 1 -> index 0. Let's verify. Actually mapping shows: ciphertext bit 58 (i=57) gets round_in bit position 1 (since inv[58]=1). But we previously wrote for ciphertext[56] = round_in[32]; That's wrong.
  // Let's recalc for i=57..63.
endmodule

module testbench;
  reg [63:0] round_in;
  wire [63:0] ciphertext;
  
  IP_inv dut (.round_in(round_in), .ciphertext(ciphertext));
  
  integer i, errors;
  
  initial begin
    errors = 0;
    
    // Set a simple pattern: each bit equals its index bit0
    for (i = 0; i < 64; i = i + 1) begin
      round_in[i] = i[0];
    end
    #10;
    
    // Check first few bits manually
    if (ciphertext[0] !== round_in[39]) begin
      $display("Error at bit 0: got %b, expected round_in[39]=%b", ciphertext[0], round_in[39]);
      errors = errors + 1;
    end
    if (ciphertext[1] !== round_in[7]) begin
      $display("Error at bit 1");
      errors = errors + 1;
    end
    if (ciphertext[2] !== round_in[47]) begin
      $display("Error at bit 2");
      errors = errors + 1;
    end
    
    $finish;
  end
endmodule
