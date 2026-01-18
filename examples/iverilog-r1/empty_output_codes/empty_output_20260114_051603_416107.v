// Verilog code that resulted in empty output
// Saved at: 2026-01-14T05:16:03.416145
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

// D latch using NAND gates
module D_latch_nand(input d, input en, output q);
  wire not_d;
  wire s_n;
  wire r_n;
  wire q_not;
  
  // Inverter using NAND
  nand inv1(not_d, d, d);
  // s_n = NOT (d & en) = NAND(d, en)
  nand nand_s(s_n, d, en);
  // r_n = NOT (~d & en) = NAND(not_d, en)
  nand nand_r(r_n, not_d, en);
  // SR latch using two NAND gates (active low inputs)
  nand nand1(q_not, s_n, q);
  nand nand2(q, r_n, q_not);
endmodule

// Master-slave D flip-flop
module D_Flip_Flop(clk, d, q);
  input clk, d;
  output q;
  
  wire master_q;
  wire slave_q;
  
  // Master latch enable is ~clk (active high)
  D_latch_nand master(.d(d), .en(~clk), .q(master_q));
  // Slave latch enable is clk (active high)
  D_latch_nand slave(.d(master_q), .en(clk), .q(slave_q));
  
  assign q = slave_q;
endmodule

// Testbench
module testbench;
  reg clk;
  reg d;
  wire q;
  wire master_q;
  
  D_Flip_Flop dut (.clk(clk), .d(d), .q(q));
  // Let's also access internal master_q? We can't directly.
  assign master_q = dut.master_q; // not possible because it's a wire inside module.
  // Instead we can create a wrapper to expose.
endmodule
