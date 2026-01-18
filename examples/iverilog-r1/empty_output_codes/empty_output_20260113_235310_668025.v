// Verilog code that resulted in empty output
// Saved at: 2026-01-13T23:53:10.668053
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

module Randomizer (
    input [15:0] ic,
    input start,
    input clk,
    output [7:0] q
);

reg [15:0] state;

wire feedback = state[15] ^ state[10] ^ state[9] ^ state[5];

always @(posedge clk) begin
    if (start)
        state <= ic;
    else
        state <= {state[14:0], feedback};
end

assign q = state[7:0];

endmodule

module testbench;
    reg [15:0] ic;
    reg start;
    reg clk;
    wire [7:0] q;

    Randomizer dut (
        .ic(ic),
        .start(start),
        .clk(clk),
        .q(q)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reference model
    reg [15:0] ref_state;
    wire ref_feedback = ref_state[15] ^ ref_state[10] ^ ref_state[9] ^ ref_state[5];
    
    always @(posedge clk) begin
        if (start)
            ref_state <= ic;
        else
            ref_state <= {ref_state[14:0], ref_feedback};
    end
    
    wire [7:0] ref_q = ref_state[7:0];

    // Stimulus
    initial begin
        // Initialize
        start = 0;
        ic = 16'h0001;
        
        // Wait for a few cycles
        #10; // Ensure setup before first posedge (posedge at time 5, 10)
        // At time 10, posedge occurs at 10? Actually clock period 10 (5 high, 5 low). First posedge at 5.
        // Let's synchronize: wait for posedge at time 5.
        // We'll apply start high at time 0, before first posedge.
        // Let's adjust: start high at time 0, ic set.
        // First posedge at 5 loads ic.
        // Then we can check.
        // Let's restart with proper timing.
        
        #100; // Wait enough time
        $finish;
    end

    // Checker
    integer cycle_count = 0;
    always @(posedge clk) begin
        if (q !== ref_q) begin
            $display("ERROR at cycle %0d: q = %h, ref_q = %h", cycle_count, q, ref_q);
            $finish;
        end
        cycle_count = cycle_count + 1;
    end

endmodule
