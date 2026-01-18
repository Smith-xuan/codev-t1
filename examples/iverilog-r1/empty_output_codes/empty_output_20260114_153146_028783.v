// Verilog code that resulted in empty output
// Saved at: 2026-01-14T15:31:46.028806
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

module demux_generate (
    input i,
    input [2:0] sel,
    output o0, o1, o2, o3, o4, o5, o6, o7
);

    wire [7:0] out_vec;
    assign {o0, o1, o2, o3, o4, o5, o6, o7} = out_vec;

    generate
        for (genvar k = 0; k < 8; k = k + 1) begin : demux_loop
            assign out_vec[k] = (sel == k) ? i : 1'b0;
        end
    endgenerate

endmodule

module testbench;
    reg i;
    reg [2:0] sel;
    wire o0, o1, o2, o3, o4, o5, o6, o7;
    
    demux_generate dut (
        .i(i),
        .sel(sel),
        .o0(o0),
        .o1(o1),
        .o2(o2),
        .o3(o3),
        .o4(o4),
        .o5(o5),
        .o6(o6),
        .o7(o7)
    );
endmodule
