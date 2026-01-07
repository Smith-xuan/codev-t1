// Verilog code that resulted in empty output
// Saved at: 2026-01-06T14:37:31.865061
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

module up_counter (
    input clock,
    output reg out,
    output reg preout
);

reg [1:0] count; // 0-2

always @(posedge clock) begin
    if (count == 2) begin
        count <= 0;
    end else begin
        count <= count + 1;
    end
end

always @(*) begin
    out = (count == 2);
    preout = (count == 1);
end

endmodule

module testbench;
    reg clock;
    wire out, preout;
    
    up_counter dut (.clock(clock), .out(out), .preout(preout));
    
    initial begin
        clock = 0;
        // Run for 10 clock cycles
        repeat (30) begin
            #0.0083333 clock = ~clock; // half period ~8.3333ms for 60Hz
        end
        $finish;
    end
endmodule
