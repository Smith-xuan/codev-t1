// Verilog code that resulted in empty output
// Saved at: 2026-01-07T04:08:26.442508
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

module ClockDivider_toggle #(
    parameter DIVISOR = 4
) (
    input wire ClockIn,
    output reg ClockOut
);
    reg [27:0] counter;
    
    always @(posedge ClockIn) begin
        if (counter == DIVISOR - 1) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
        
        if (counter == (DIVISOR-1)/2 || counter == DIVISOR-1) begin
            ClockOut <= ~ClockOut;
        end
    end
    
    initial begin
        counter = 0;
        ClockOut = 0;
    end
endmodule

module testbench;
    reg clk;
    wire out;
    
    ClockDivider_toggle #(.DIVISOR(3)) dut (.ClockIn(clk), .ClockOut(out));
    
    integer cycle = 0;
    initial begin
        clk = 0;
        #200 $finish;
    end
    
    always @(posedge clk) begin
        $display("Time=%0t, counter=%0d, out=%b", $time, dut.counter, out);
        cycle = cycle + 1;
    end
endmodule
