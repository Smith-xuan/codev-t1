// Verilog code that resulted in empty output
// Saved at: 2026-01-14T14:44:14.747731
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

module delay #(parameter C_CLOCK_CYCLES = 3) (
    input id,
    input iclk,
    output oq
);
    // Handle zero delay case
    generate
        if (C_CLOCK_CYCLES == 0) begin
            assign oq = id;
        end else begin
            // Shift register of width C_CLOCK_CYCLES
            reg [C_CLOCK_CYCLES-1:0] shift_reg = 0;
            always @(posedge iclk) begin
                shift_reg <= {shift_reg[C_CLOCK_CYCLES-2:0], id};
            end
            assign oq = shift_reg[C_CLOCK_CYCLES-1];
        end
    endgenerate
endmodule

module testbench;
    // Test with C_CLOCK_CYCLES = 3
    parameter DELAY = 3;
    reg id;
    reg iclk;
    wire oq;
    
    delay #(.C_CLOCK_CYCLES(DELAY)) dut (.id(id), .iclk(iclk), .oq(oq));
    
    initial begin
        iclk = 0;
        id = 0;
        #5 iclk = 1; #5 iclk = 0; // clock period 10
        
        // Test sequence
        // Start with id = 1 at time 0
        id = 1;
        @(posedge iclk);
        // After each clock, check oq
        repeat (10) begin
            $display("time = %0t, id = %b, oq = %b", $time, id, oq);
            @(posedge iclk);
        end
    end
    
endmodule
