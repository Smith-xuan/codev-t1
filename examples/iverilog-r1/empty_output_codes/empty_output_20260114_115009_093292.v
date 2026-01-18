// Verilog code that resulted in empty output
// Saved at: 2026-01-14T11:50:09.093341
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

module clk_div_disp(
    input clk,
    input reset,
    output time_clk,
    output slow_clk
);

// Parameters for counters
localparam SLOW_COUNT_MAX = 39999;  // 40000 cycles total period (0 to 39999)
localparam TIME_COUNT_MAX = 999999; // 1,000,000 cycles total period (0 to 999999)

reg [15:0] slow_counter; // 16 bits sufficient for 0-65535
reg [19:0] time_counter; // 20 bits sufficient

// Counters with automatic reset at period end
always @(posedge clk) begin
    if (reset) begin
        slow_counter <= 0;
    end else if (slow_counter == SLOW_COUNT_MAX) begin
        slow_counter <= 0;
    end else begin
        slow_counter <= slow_counter + 1;
    end
end

always @(posedge clk) begin
    if (reset) begin
        time_counter <= 0;
    end else if (time_counter == TIME_COUNT_MAX) begin
        time_counter <= 0;
    end else begin
        time_counter <= time_counter + 1;
    end
end

// Clock outputs: high for first half of period
assign slow_clk = (slow_counter < 20000); // half-period is 20000 cycles
assign time_clk = (time_counter < 500000); // half-period is 500,000 cycles

endmodule

module testbench;
    reg clk;
    reg reset;
    wire time_clk;
    wire slow_clk;
    
    clk_div_disp dut (
        .clk(clk),
        .reset(reset),
        .time_clk(time_clk),
        .slow_clk(slow_clk)
    );
    
    // Generate 100 MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        // Apply reset
        reset = 1;
        #20;
        reset = 0;
        
        // Monitor for a while
        #2000020; // 2,000,020 ns (enough to see many toggles)
        $finish;
    end
    
    // Monitor at each posedge
    integer cycle_count = 0;
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        //$display("Cycle %0d: slow_counter=%0d, slow_clk=%b, time_counter=%0d, time_clk=%b", cycle_count, dut.slow_counter, slow_clk, dut.time_counter, time_clk);
    end
endmodule
