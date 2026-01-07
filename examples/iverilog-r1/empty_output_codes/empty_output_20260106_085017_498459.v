// Verilog code that resulted in empty output
// Saved at: 2026-01-06T08:50:17.498484
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

module johnson_counter(
    input clk,
    input reset,
    output reg [3:0] out
);

always @(posedge clk) begin
    if (reset) out <= 4'b0000;
    else begin
        out[0] <= ~out[3];
        out[1] <= out[0];
        out[2] <= out[1];
        out[3] <= out[2];
    end
end

endmodule

module testbench;
reg clk;
reg reset;
wire [3:0] out;

johnson_counter dut (.clk(clk), .reset(reset), .out(out));

reg [3:0] expected;
integer errors = 0;
integer cycle = 0;

task check_sequence;
    input [3:0] expected_val;
    begin
        if (out !== expected_val) begin
            $display("Error at cycle %0d: out = %b, expected = %b", cycle, out, expected_val);
            errors = errors + 1;
        end
        cycle = cycle + 1;
    end
endtask

initial begin
    clk = 0;
    reset = 1;
    // Wait for posedge
    @(posedge clk);
    // Assert reset for one cycle
    reset = 1;
    @(posedge clk);
    reset = 0;
    
    // Sequence expected after reset
    // Cycle 0 (after reset): 0000
    check_sequence(4'b0000);
    // Cycle 1: 0001
    @(posedge clk);
    check_sequence(4'b0001);
    // Cycle 2: 0011
    @(posedge clk);
    check_sequence(4'b0011);
    // Cycle 3: 0111
    @(posedge clk);
    check_sequence(4'b0111);
    // Cycle 4: 1111
    @(posedge clk);
    check_sequence(4'b1111);
    // Cycle 5: 1110
    @(posedge clk);
    check_sequence(4'b1110);
    // Cycle 6: 1100
    @(posedge clk);
    check_sequence(4'b1100);
    // Cycle 7: 1000
    @(posedge clk);
    check_sequence(4'b1000);
    // Cycle 8: 0000 (repeat)
    @(posedge clk);
    check_sequence(4'b0000);
    // Cycle 9: 0001
    @(posedge clk);
    check_sequence(4'b0001);
    
    if (errors == 0)
        $display("All tests passed!");
    else
        $display("Failed with %0d errors", errors);
    
    $finish;
end

endmodule
