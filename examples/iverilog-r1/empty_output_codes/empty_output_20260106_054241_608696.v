// Verilog code that resulted in empty output
// Saved at: 2026-01-06T05:42:41.608735
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

module acc_control (
    input clk,
    input rst,
    output reg sel,
    output reg en
);

    // State encoding
    localparam S1 = 2'b00;
    localparam S2 = 2'b01;
    localparam S3 = 2'b10;
    localparam S4 = 2'b11;

    // State register
    reg [1:0] state, next_state;

    // Sequential state transition
    always @(posedge clk) begin
        if (rst) begin
            state <= S1;
        end else begin
            state <= next_state;
        end
    end

    // Combinational next state and output logic
    always @(*) begin
        // Default outputs
        sel = (state == S1);
        en = (state == S4);
        next_state = state; // default stay in current state

        case (state)
            S1: next_state = S2;
            S2: next_state = S3;
            S3: next_state = S4;
            S4: next_state = S1;
            default: next_state = S1;
        endcase
    end

endmodule

module testbench;
    reg clk;
    reg rst;
    wire sel;
    wire en;

    // Instantiate DUT
    acc_control dut (.*);

    // Clock generation with finite cycles
    initial begin
        clk = 0;
        repeat (20) begin
            #5 clk = ~clk;
        end
    end

    // Test sequence
    initial begin
        // Initialize
        rst = 1;
        #10; // Wait for a clock edge
        if (sel !== 1'b1 || en !== 1'b0) begin
            $display("ERROR: Reset state incorrect: sel=%b, en=%b", sel, en);
            $finish;
        end

        // Release reset and check state transitions
        rst = 0;
        #10; // Wait for next posedge (now state should be S2)
        if (sel !== 1'b0 || en !== 1'b0) begin
            $display("ERROR: After first transition, sel=%b (expected 0), en=%b (expected 0)", sel, en);
            $finish;
        end
        #10; // S3
        if (sel !== 1'b0 || en !== 1'b0) begin
            $display("ERROR: At S3, sel=%b (expected 0), en=%b (expected 0)", sel, en);
            $finish;
        end
        #10; // S4
        if (sel !== 1'b0 || en !== 1'b1) begin
            $display("ERROR: At S4, sel=%b (expected 0), en=%b (expected 1)", sel, en);
            $finish;
        end
        #10; // back to S1
        if (sel !== 1'b1 || en !== 1'b0) begin
            $display("ERROR: Back to S1, sel=%b (expected 1), en=%b (expected 0)", sel, en);
            $finish;
        end

        // Additional cycles
        #10; // S2
        if (sel !== 0 || en !== 0) begin
            $display("ERROR: S2 mismatch");
            $finish;
        end
        #10; // S3
        if (sel !== 0 || en !== 0) begin
            $display("ERROR: S3 mismatch");
            $finish;
        end
        #10; // S4
        if (sel !== 0 || en !== 1) begin
            $display("ERROR: S4 mismatch");
            $finish;
        end
        #10; // S1
        if (sel !== 1 || en !== 0) begin
            $display("ERROR: S1 mismatch");
            $finish;
        end

        // Test reset during operation
        #5; // half cycle to get to posedge? Let's wait for posedge explicitly
        @(posedge clk);
        #1;
        rst = 1;
        @(posedge clk);
        #1;
        if (sel !== 1'b1 || en !== 1'b0) begin
            $display("ERROR: After reset during operation, sel=%b (expected 1), en=%b (expected 0)", sel, en);
            $finish;
        end
        rst = 0;
        @(posedge clk);
        #1;
        if (sel !== 0 || en !== 0) begin
            $display("ERROR: After reset release, state should be S2");
            $finish;
        end

        $display("All tests passed!");
        $finish;
    end

endmodule
