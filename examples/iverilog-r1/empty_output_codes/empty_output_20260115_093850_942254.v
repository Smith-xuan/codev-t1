// Verilog code that resulted in empty output
// Saved at: 2026-01-15T09:38:50.942284
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

`timescale 1ns/1ns

module FiftyMegaHzToFiveMegaHz (
    input FiftyIn,
    output FiveOut
);
    reg [3:0] counter;
    reg out;
    
    always @(posedge FiftyIn) begin
        if (counter == 4'd10) begin
            counter <= 4'd0;
            out <= ~out;
        end else begin
            counter <= counter + 1;
        end
    end
    
    assign FiveOut = out;
    
    initial begin
        counter = 0;
        out = 0;
    end
endmodule

module testbench;
    reg FiftyIn;
    wire FiveOut;
    
    FiftyMegaHzToFiveMegaHz dut (
        .FiftyIn(FiftyIn),
        .FiveOut(FiveOut)
    );
    
    initial begin
        FiftyIn = 0;
        #20000 $finish;
    end
    
    always #10 FiftyIn = ~FiftyIn; // 50 MHz period 20 ns? Actually period = 20 ns => half period = 10 ns. So toggle every 10 ns.
endmodule
