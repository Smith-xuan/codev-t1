// Verilog code that resulted in empty output
// Saved at: 2026-01-14T17:41:35.401720
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

module ShiftRows (
    input wire [127:0] IN_state,
    output wire [127:0] OUT_state
);

wire [7:0] in_byte [0:15];

assign in_byte[0]  = IN_state[127:120];
assign in_byte[1]  = IN_state[119:112];
assign in_byte[2]  = IN_state[111:104];
assign in_byte[3]  = IN_state[103:96];
assign in_byte[4]  = IN_state[95:88];
assign in_byte[5]  = IN_state[87:80];
assign in_byte[6]  = IN_state[79:72];
assign in_byte[7]  = IN_state[71:64];
assign in_byte[8]  = IN_state[63:56];
assign in_byte[9]  = IN_state[55:48];
assign in_byte[10] = IN_state[47:40];
assign in_byte[11] = IN_state[39:32];
assign in_byte[12] = IN_state[31:24];
assign in_byte[13] = IN_state[23:16];
assign in_byte[14] = IN_state[15:8];
assign in_byte[15] = IN_state[7:0];

assign OUT_state = {
    in_byte[0],   // byte0
    in_byte[5],   // byte1
    in_byte[10],  // byte2
    in_byte[15],  // byte3
    in_byte[4],   // byte4
    in_byte[9],   // byte5
    in_byte[14],  // byte6
    in_byte[3],   // byte7
    in_byte[8],   // byte8
    in_byte[13],  // byte9
    in_byte[2],   // byte10
    in_byte[7],   // byte11
    in_byte[12],  // byte12
    in_byte[1],   // byte13
    in_byte[6],   // byte14
    in_byte[11]   // byte15
};

endmodule

module testbench;
    reg [127:0] IN_state;
    wire [127:0] OUT_state;
    
    ShiftRows dut (.IN_state(IN_state), .OUT_state(OUT_state));
    
    initial begin
        // Test case 1: incremental bytes 0..15
        IN_state[127:120] = 8'h00;
        IN_state[119:112] = 8'h01;
        IN_state[111:104] = 8'h02;
        IN_state[103:96]  = 8'h03;
        IN_state[95:88]   = 8'h04;
        IN_state[87:80]   = 8'h05;
        IN_state[79:72]   = 8'h06;
        IN_state[71:64]   = 8'h07;
        IN_state[63:56]   = 8'h08;
        IN_state[55:48]   = 8'h09;
        IN_state[47:40]   = 8'h0A;
        IN_state[39:32]   = 8'h0B;
        IN_state[31:24]   = 8'h0C;
        IN_state[23:16]   = 8'h0D;
        IN_state[15:8]    = 8'h0E;
        IN_state[7:0]     = 8'h0F;
        
        #10;
        
        // Expected output based on mapping:
        // MSB to LSB bytes: 00 05 0A 0F 04 09 0E 03 08 0D 02 07 0C 01 06 0B
        if (OUT_state[127:120] != 8'h00) $display("ERROR: byte0 mismatch, got %h", OUT_state[127:120]);
        if (OUT_state[119:112] != 8'h05) $display("ERROR: byte1 mismatch, got %h", OUT_state[119:112]);
        if (OUT_state[111:104] != 8'h0A) $display("ERROR: byte2 mismatch, got %h", OUT_state[111:104]);
        if (OUT_state[103:96]  != 8'h0F) $display("ERROR: byte3 mismatch, got %h", OUT_state[103:96]);
        if (OUT_state[95:88]   != 8'h04) $display("ERROR: byte4 mismatch, got %h", OUT_state[95:88]);
        if (OUT_state[87:80]   != 8'h09) $display("ERROR: byte5 mismatch, got %h", OUT_state[87:80]);
        if (OUT_state[79:72]   != 8'h0E) $display("ERROR: byte6 mismatch, got %h", OUT_state[79:72]);
        if (OUT_state[71:64]   != 8'h03) $display("ERROR: byte7 mismatch, got %h", OUT_state[71:64]);
        if (OUT_state[63:56]   != 8'h08) $display("ERROR: byte8 mismatch, got %h", OUT_state[63:56]);
        if (OUT_state[55:48]   != 8'h0D) $display("ERROR: byte9 mismatch, got %h", OUT_state[55:48]);
        if (OUT_state[47:40]   != 8'h02) $display("ERROR: byte10 mismatch, got %h", OUT_state[47:40]);
        if (OUT_state[39:32]   != 8'h07) $display("ERROR: byte11 mismatch, got %h", OUT_state[39:32]);
        if (OUT_state[31:24]   != 8'h0C) $display("ERROR: byte12 mismatch, got %h", OUT_state[31:24]);
        if (OUT_state[23:16]   != 8'h01) $display("ERROR: byte13 mismatch, got %h", OUT_state[23:16]);
        if (OUT_state[15:8]    != 8'h06) $display("ERROR: byte14 mismatch, got %h", OUT_state[15:8]);
        if (OUT_state[7:0]     != 8'h0B) $display("ERROR: byte15 mismatch, got %h", OUT_state[7:0]);
        
        if ($test$plusargs("verbose")) $display("Test completed.");
        $finish;
    end
endmodule
