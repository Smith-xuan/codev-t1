// Verilog code that resulted in empty output
// Saved at: 2026-01-05T22:41:59.778973
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

`timescale 1ns/1ps

module bk_ay_orig (
    input strobe,
    input iwrbt,
    output bc1,
    output bc2,
    output bdir
);
    assign bc2 = 1'b1;
    assign bdir = strobe;
    assign bc1 = iwrbt & strobe;
endmodule

module cmd_ay_orig (
    input strobe,
    input iwrbt,
    input dout,
    output ay_inact,
    output ay_laddr,
    output ay_wrpsg,
    output ay_rdpsg
);
    wire bc1_internal, bc2_internal, bdir_internal;
    bk_ay_orig u_bk_ay_orig (.strobe(strobe), .iwrbt(iwrbt),
                             .bc1(bc1_internal), .bc2(bc2_internal),
                             .bdir(bdir_internal));
    
    assign ay_inact = (~bdir_internal & ~bc1_internal) |
                     (bdir_internal & ~bc2_internal & bc1_internal);
    assign ay_laddr = bdir_internal & bc1_internal;
    assign ay_wrpsg = bdir_internal & bc1_internal;
    assign ay_rdpsg = ~bdir_internal & bc1_internal;
endmodule

module testbench;
    reg strobe;
    reg iwrbt;
    reg dout;
    wire ay_inact, ay_laddr, ay_wrpsg, ay_rdpsg;
    
    cmd_ay_orig dut (.strobe(strobe), .iwrbt(iwrbt), .dout(dout),
                     .ay_inact(ay_inact), .ay_laddr(ay_laddr),
                     .ay_wrpsg(ay_wrpsg), .ay_rdpsg(ay_rdpsg));
    
    initial begin
        strobe = 0; iwrbt = 0; dout = 0;
        #10;
        strobe = 1;
        #10;
        iwrbt = 1;
        #10;
        strobe = 0;
        #10;
        $finish;
    end
endmodule
