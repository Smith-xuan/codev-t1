// Verilog code that resulted in empty output
// Saved at: 2026-01-15T04:29:47.581894
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

module JKFF (
    input J,
    input K,
    input CLK,
    output reg Q
);
always @(posedge CLK) begin
    case ({J,K})
        2'b00: Q <= Q;   // hold
        2'b01: Q <= 1'b0; // reset
        2'b10: Q <= 1'b1; // set
        2'b11: Q <= ~Q;   // toggle
        default: Q <= Q;
    endcase
end
endmodule

module DLatch (
    input D,
    input CLK,
    output reg Q
);
always @(posedge CLK) begin
    Q <= D;
end
endmodule

module Counter (
    input RN,
    input CLK,
    output [1:0] Q
);
wire Q0, Q1;
wire J0, K0, J1, K1;

// For bit0 (LSB): toggle when not reset, else set to 0
assign J0 = RN ? 1'b0 : 1'b1;
assign K0 = RN ? 1'b1 : 1'b1;

// For bit1: toggle when Q0=1, else set to 0 when reset
assign J1 = RN ? 1'b0 : Q0;
assign K1 = RN ? 1'b1 : Q0;

JKFF bit0 (.J(J0), .K(K0), .CLK(CLK), .Q(Q0));
JKFF bit1 (.J(J1), .K(K1), .CLK(CLK), .Q(Q1));

assign Q = {Q1, Q0};
endmodule

module testbench;
    reg RN, CLK;
    wire [1:0] Q;
    reg J, K, D;
    wire Q_JK, Q_DL;
    
    JKFF u_jkff (.J(J), .K(K), .CLK(CLK), .Q(Q_JK));
    DLatch u_dlatch (.D(D), .CLK(CLK), .Q(Q_DL));
    Counter u_counter (.RN(RN), .CLK(CLK), .Q(Q));
    
    initial begin
        // Initialize signals
        CLK = 0;
        RN = 0;
        J = 0;
        K = 0;
        D = 0;
        
        // Apply reset
        RN = 1;
        @(posedge CLK);
        RN = 0;
        @(posedge CLK);
        @(posedge CLK);
        @(posedge CLK);
        @(posedge CLK);
        @(posedge CLK);
        
        $finish;
    end
    
    // Clock generation
    always #5 CLK = ~CLK;
endmodule
