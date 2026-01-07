// Verilog code that resulted in empty output
// Saved at: 2026-01-06T03:12:04.247766
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

module borrow_lookahead_subtractor_4bit(
  input [3:0] X,
  input [3:0] Y,
  input Bin,
  output [3:0] Diff,
  output Bout
);
  // Borrow signals: B[0] = Bin, B[4] = Bout
  wire [4:0] B;
  assign B[0] = Bin;
  
  // Propagate and generate signals for each bit
  // P_i = X_i (borrow propagates when X_i = 1)
  // G_i = ~X_i & Y_i (borrow generated when X_i = 0 and Y_i = 1)
  // Borrow recurrence: B[i] = P_i & B[i-1] | G_i
  
  assign B[1] = (X[0] & B[0]) | (~X[0] & Y[0]);
  assign B[2] = (X[1] & B[1]) | (~X[1] & Y[1]);
  assign B[3] = (X[2] & B[2]) | (~X[2] & Y[2]);
  assign B[4] = (X[3] & B[3]) | (~X[3] & Y[3]);
  
  // Difference bits: Diff_i = X_i ^ B[i] (since borrow into bit i is B[i])
  assign Diff[0] = X[0] ^ B[1];
  assign Diff[1] = X[1] ^ B[2];
  assign Diff[2] = X[2] ^ B[3];
  assign Diff[3] = X[3] ^ B[4];
  assign Bout = B[4];
endmodule

module testbench;
  reg [3:0] X, Y;
  reg Bin;
  wire [3:0] Diff, Diff_ref;
  wire Bout, Bout_ref;
  
  borrow_lookahead_subtractor_4bit dut(.X(X), .Y(Y), .Bin(Bin), .Diff(Diff), .Bout(Bout));
  
  // Reference using Verilog subtraction operator
  assign {Bout_ref, Diff_ref} = X - Y - Bin;
  
  integer i;
  initial begin
    // exhaustive test
    for (i = 0; i < 1024; i = i + 1) begin
      {X, Y, Bin} = i;  // i[31:24] unused, i[23:16] unused, i[15:8] X, i[7:4] Y, i[3:0] Bin? Actually 4+4+1=9 bits.
      // Use concatenation: {X,Y,Bin} = {2 bits unused, X, Y, Bin}. Let's do proper.
      // We'll compute manually.
    end
    // Let's use simpler: separate loops.
  end
endmodule
