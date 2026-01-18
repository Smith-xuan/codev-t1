// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:40:35.887234
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

module Timer(
    input clk,
    input start,
    output reg done
);
    reg [31:0] counter;
    
    always @(posedge clk) begin
        if (start) begin
            if (counter == 32'hFFFFFFFF) begin
                counter <= 32'h0;
                done <= 1'b1;
            end else begin
                counter <= counter + 1;
                done <= 1'b0;
            end
        end else begin
            counter <= counter;
            done <= 1'b0;
        end
    end
endmodule

module testbench;
    reg clk;
    reg start;
    wire done;
    
    Timer dut (.clk(clk), .start(start), .done(done));
    
    initial begin
        clk = 0;
        start = 0;
        #10 start = 1;
        #10 start = 0;
        #100 $finish;
    end
    
    always #5 clk = ~clk;
endmodule
