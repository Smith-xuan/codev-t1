// Verilog code that resulted in empty output
// Saved at: 2026-01-14T16:39:59.140534
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

module vertical_counter (
    input clk_25,
    input enable_V_counter,
    output reg [15:0] v_counter_value
);

always @(posedge clk_25) begin
    if (enable_V_counter) begin
        if (v_counter_value == 16'd524) begin
            v_counter_value <= 16'd0;
        end else begin
            v_counter_value <= v_counter_value + 1;
        end
    end
end

endmodule

module testbench;
    reg clk_25;
    reg enable_V_counter;
    wire [15:0] v_counter_value;
    
    vertical_counter dut (
        .clk_25(clk_25),
        .enable_V_counter(enable_V_counter),
        .v_counter_value(v_counter_value)
    );
    
    initial begin
        clk_25 = 0;
        enable_V_counter = 0;
        #100;
        enable_V_counter = 1;
        // Wait for some cycles
        repeat (530) @(posedge clk_25);
        $finish;
    end
    
    always #20 clk_25 = ~clk_25;
endmodule
