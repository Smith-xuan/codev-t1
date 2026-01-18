// Verilog code that resulted in empty output
// Saved at: 2026-01-14T13:08:08.149469
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

module encoder (
    input [15:0] a,
    output [3:0] y
);
    // Simple OR tree (no precedence)
    assign y[0] = a[1] | a[3] | a[5] | a[7] | a[9] | a[11] | a[13] | a[15];
    assign y[1] = a[2] | a[3] | a[6] | a[7] | a[10] | a[11] | a[14] | a[15];
    assign y[2] = a[4] | a[5] | a[6] | a[7] | a[12] | a[13] | a[14] | a[15];
    assign y[3] = a[8] | a[9] | a[10] | a[11] | a[12] | a[13] | a[14] | a[15];
endmodule

module testbench;
    reg [15:0] a;
    wire [3:0] y;
    reg [3:0] expected;
    
    encoder dut (.a(a), .y(y));
    
    integer i, j;
    initial begin
        for (i = 0; i < 65536; i = i + 1) begin
            a = i;
            // compute expected index of first '1' from LSB (highest priority)
            expected = 16'd0;
            for (j = 0; j < 16; j = j + 1) begin
                if (a[j]) begin
                    expected = j;
                    // break; // not supported, so we use disable
                end
            end
            // We can set expected after finding first bit, then disable loop? 
            // Actually we can use a simple while loop.
            // Let's try a different approach: use a while loop that scans bits.
            // But we can also compute using a lexicographical scan.
            // Let's just use integer loop and break by using break; 
            // using unsupported construct, but we can use disable.
            // Let's create a task.
        end
    end
endmodule
