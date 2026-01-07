// Verilog code that resulted in empty output
// Saved at: 2026-01-06T03:15:25.047717
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

module top_module (
    input clk,
    input reset,
    output reg [2:0] ena,
    output reg [15:0] q
);

wire [3:0] next_low;
wire [3:0] next_mid;
wire [3:0] next_high;
wire [3:0] next_thigh;
wire carry0, carry1, carry2, carry3;

// compute carry chain
assign carry0 = (q[3:0] == 4'd9);
assign next_low = carry0 ? 4'd0 : q[3:0] + 1'b1;

wire [4:0] sum_mid = q[7:4] + {1'b0, carry0};
assign carry1 = (sum_mid >= 5'd10);
assign next_mid = carry1 ? 4'd0 : sum_mid[3:0];

wire [4:0] sum_high = q[11:8] + {1'b0, carry1};
assign carry2 = (sum_high >= 5'd10);
assign next_high = carry2 ? 4'd0 : sum_high[3:0];

wire [4:0] sum_thigh = q[15:12] + {1'b0, carry2};
assign carry3 = (sum_thigh >= 5'd10);
assign next_thigh = carry3 ? 4'd0 : sum_thigh[3:0];

wire [15:0] next_q_full = {next_thigh, next_high, next_mid, next_low};

// update q on rising edge
always @(posedge clk) begin
    if (reset) begin
        q <= 16'd0;
    end else begin
        q <= next_q_full;
    end
end

// compute enable outputs
always @(*) begin
    ena[0] = (q[3:0] == 4'd9);
    ena[1] = (q[7:0] == 8'd99);
    ena[2] = (q[11:0] == 12'd999);
end

endmodule

// Testbench
module testbench;
reg clk;
reg reset;
wire [2:0] ena;
wire [15:0] q;

top_module dut (.clk(clk), .reset(reset), .ena(ena), .q(q));

initial begin
    clk = 0;
    reset = 1;
    // Wait for first posedge
    @(posedge clk);
    // Deassert reset after one clock cycle
    #1 reset = 0;
    
    // Monitor
    $display("Time\t clk\t reset\t q\t\t\t\t ena");
    $monitor("%4d\t %b\t %b\t %h (BCD %d%d%d%d)\t %b", $time, clk, reset, q, q[15:12], q[11:8], q[7:4], q[3:0], ena);
    
    // Check reset behavior
    // Wait for next posedge to see q initialized
    @(posedge clk);
    if (q !== 16'h0) $error("Reset failed: q not zero after reset");
    else $display("Reset passed: q = 0");
    
    // Count up and verify BCD progression
    // We'll expect counting: 0,1,2,...,9,10,11,...,99,100,...,999,1000,...,9999,0
    // Let's run for 35 cycles (covers up to 35 decimal)
    repeat (35) @(posedge clk); // wait for posedge each time
    
    // Specific check: after 10 cycles (should be 10 decimal = BCD 0000 0001 0000)
    // We'll capture at posedge before increment? Actually we've already advanced.
    // Instead we'll create a separate test sequence.
    $display("Simulation completed");
    $finish;
end

endmodule
