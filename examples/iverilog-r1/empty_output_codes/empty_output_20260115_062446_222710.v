// Verilog code that resulted in empty output
// Saved at: 2026-01-15T06:24:46.222739
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

module reset (
    input clk,
    output reg reset
);

parameter COUNT_MAX = 500_000 - 1; // 499,999

reg [18:0] count; // enough bits: 2^19 = 524288 > 500000

initial begin
    count = 0;
    reset = 0;
end

always @(posedge clk) begin
    if (count == COUNT_MAX) begin
        count <= 0;
        reset <= 1'b1;
    end else begin
        count <= count + 1;
        reset <= 1'b0;
    end
end

endmodule

module testbench;
    reg clk;
    wire reset;
    
    // Instantiate DUT
    reset dut (.clk(clk), .reset(reset));
    
    initial begin
        clk = 0;
        // Run for a limited time
        #1000000 $finish;
    end
    
    always #10 clk = ~clk; // 50 MHz period 20 ns
    
    // Monitor reset pulses
    reg [31:0] last_pulse_time = 0;
    reg [31:0] pulse_count = 0;
    integer cycle_count = 0;
    
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (reset) begin
            $display("Reset pulse at cycle %0d, time %0t", cycle_count, $time);
            if (last_pulse_time != 0) begin
                $display("  Period since last pulse: %0d cycles", $time - last_pulse_time);
            end
            last_pulse_time = $time;
            pulse_count <= pulse_count + 1;
        end
    end
    
endmodule
