// Verilog code that resulted in empty output
// Saved at: 2026-01-14T09:50:46.374365
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

module my_clock_divider (
    input clock_in,
    output reg clock_out
);

reg [14:0] counter = 0;

always @(posedge clock_in) begin
    if (counter == 15'd23999) begin
        clock_out <= ~clock_out;
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end

endmodule

module testbench;
    reg clock_in;
    wire clock_out;
    
    my_clock_divider dut (
        .clock_in(clock_in),
        .clock_out(clock_out)
    );
    
    // Generate clock with period 10 time units
    initial begin
        clock_in = 0;
        forever #5 clock_in = ~clock_in;
    end
    
    integer cycle_count = 0;
    integer last_toggle_time = 0;
    integer toggle_count = 0;
    
    // Monitor toggles
    always @(posedge clock_in) begin
        cycle_count = cycle_count + 1;
    end
    
    always @(clock_out) begin
        $display("Toggle at time %0t, cycle count = %0d", $time, cycle_count);
        toggle_count = toggle_count + 1;
        if (toggle_count > 2) $finish;
    end
    
    initial begin
        // Wait for enough cycles
        #1000000 $finish;
    end
    
endmodule
