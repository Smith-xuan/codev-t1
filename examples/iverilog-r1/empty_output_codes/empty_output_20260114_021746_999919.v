// Verilog code that resulted in empty output
// Saved at: 2026-01-14T02:17:46.999951
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

// D latch module using NOR and NOT gates
module d_latch (
    input D,
    input en,
    output Q,
    output Q_bar
);

wire notD = ~D;
wire notEn = ~en;

wire term1;
nor (term1, notD, notEn); // term1 = D & en

wire S_bar;
not (S_bar, term1); // S_bar = NOT (D & en)

wire term2;
nor (term2, D, notEn); // term2 = NOT D & en

wire R_bar;
not (R_bar, term2); // R_bar = NOT (NOT D & en) = D OR NOT en

// SR latch using cross-coupled NOR gates
wire q_net, qb_net;
nor (q_net, S_bar, qb_net);
nor (qb_net, R_bar, q_net);

assign Q = q_net;
assign Q_bar = qb_net;

endmodule

// D flip-flop using two latches
module d_flip_flop (
    input D,
    input CLK,
    output Q,
    output NQ
);

wire clk_n = ~CLK;  // inverted clock

wire master_Q, master_Q_bar;
wire slave_Q, slave_Q_bar;

d_latch master_latch (
    .D(D),
    .en(clk_n),
    .Q(master_Q),
    .Q_bar(master_Q_bar)
);

d_latch slave_latch (
    .D(master_Q),
    .en(CLK),
    .Q(slave_Q),
    .Q_bar(slave_Q_bar)
);

assign Q = slave_Q;
assign NQ = slave_Q_bar;

endmodule

// Testbench for D flip-flop
module testbench;
reg D, CLK;
wire Q, NQ;

d_flip_flop dut (.D(D), .CLK(CLK), .Q(Q), .NQ(NQ));

initial begin
    // Initialize
    CLK = 0;
    D = 0;
    #10;
    
    // Test 1: D=0, rising edge, Q should stay 0 (initialized unknown but after first edge)
    CLK = 1; #10; CLK = 0; #10;
    // At this point, after rising edge, master latch captured D=0 on rising edge? Wait timing.
    // Let's think: At time 0, CLK=0, master enable = clk_n = 1 (since CLK=0, ~CLK=1). So master transparent, Q_master follows D=0.
    // Slave enable = CLK = 0, slave hold previous (unknown).
    // When CLK rises at time 10? Actually we set CLK=1 at time? Let's define proper test.
    // We'll create a clock waveform and data changes at specific times.
    
    // Let's restart with clear test sequence:
    
    // Reset test: we cannot reset hard, but we can assume initial state is unknown.
    // We'll apply clock edges and check behavior.
end
endmodule
