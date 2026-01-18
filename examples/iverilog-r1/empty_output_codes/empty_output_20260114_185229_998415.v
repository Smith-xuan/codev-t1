// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:52:29.998444
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

module sec_10 #(parameter PRESCALER_MAX = 4) (
    input clk,
    input reset,
    output [7:0] dout
);

    reg [31:0] prescaler;
    reg [3:0] sec;
    wire enable_1hz;

    assign enable_1hz = (prescaler == PRESCALER_MAX);

    always @(posedge clk) begin
        if (reset) begin
            prescaler <= 0;
            sec <= 0;
        end else begin
            // Update prescaler
            if (prescaler == PRESCALER_MAX) begin
                prescaler <= 0;
            end else begin
                prescaler <= prescaler + 1;
            end

            // Update decimal counter on 1Hz enable
            if (enable_1hz) begin
                if (sec == 9) begin
                    sec <= 0;
                end else begin
                    sec <= sec + 1;
                end
            end
        end
    end

    // 7-segment decoder (common cathode, active high segments)
    // dout[7] = dp, dout[6] = g, dout[5] = f, dout[4] = e, dout[3] = d, dout[2] = c, dout[1] = b, dout[0] = a
    assign dout = (sec == 4'd0) ? 8'h3F :
                  (sec == 4'd1) ? 8'h06 :
                  (sec == 4'd2) ? 8'h5B :
                  (sec == 4'd3) ? 8'h4F :
                  (sec == 4'd4) ? 8'h66 :
                  (sec == 4'd5) ? 8'h6D :
                  (sec == 4'd6) ? 8'h7D :
                  (sec == 4'd7) ? 8'h07 :
                  (sec == 4'd8) ? 8'h7F :
                  /* sec == 4'd9 */ 8'h6F;

endmodule

module testbench;
    reg clk;
    reg reset;
    wire [7:0] dout;

    // Use a small prescaler max for simulation
    sec_10 #(.PRESCALER_MAX(9)) dut (.clk(clk), .reset(reset), .dout(dout));
    // PRESCALER_MAX = 9 means count 0-9 (10 cycles) per second.

    // Expected 7-seg patterns for digits 0-9
    wire [7:0] expected [0:9];
    assign expected[0] = 8'h3F;
    assign expected[1] = 8'h06;
    assign expected[2] = 8'h5B;
    assign expected[3] = 8'h4F;
    assign expected[4] = 8'h66;
    assign expected[5] = 8'h6D;
    assign expected[6] = 8'h7D;
    assign expected[7] = 8'h07;
    assign expected[8] = 8'h7F;
    assign expected[9] = 8'h6F;

    integer cycle_count;
    integer sec_count;
    reg [3:0] prev_sec;

    initial begin
        clk = 0;
        reset = 1;
        cycle_count = 0;
        sec_count = 0;
        prev_sec = 0;

        // Apply reset for 5 cycles
        repeat (5) begin
            #10 clk = ~clk;
        end

        reset = 0;

        // Monitor for up to 100 clock cycles (should see many seconds)
        repeat (100) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            $display("Cycle %0d: sec=%d, dout=%h, expected=%h", 
                     cycle_count, dut.sec, dout, expected[dut.sec]);

            // Check that dout matches expected pattern for current sec
            if (dout !== expected[dut.sec]) begin
                $error("ERROR: dout mismatch at sec=%d: got %h, expected %h",
                       dut.sec, dout, expected[dut.sec]);
            end

            // Detect when sec changes and verify wrap-around
            if (dut.sec !== prev_sec) begin
                if (prev_sec != 0) begin
                    $display("  Sec changed from %d to %d", prev_sec, dut.sec);
                end
                prev_sec = dut.sec;

                // Verify that sec increments correctly across wraps
                if (prev_sec == 9) begin
                    if (dut.sec != 0) begin
                        $error("ERROR: sec did not wrap from 9 to 0, got %d", dut.sec);
                    end else begin
                        $display("  Wrap from 9 to 0 successful");
                    end
                end
            end
        end

        // Test reset again
        $display("\nApplying reset...");
        reset = 1;
        repeat (5) @(posedge clk);
        if (dut.sec !== 0) begin
            $error("ERROR: After reset, sec=%d, expected 0", dut.sec);
        end
        if (dout !== 8'h3F) begin
            $error("ERROR: After reset, dout=%h, expected 3F", dout);
        end
        $display("After reset: sec=%d, dout=%h", dut.sec, dout);

        reset = 0;
        @(posedge clk);
        $display("\nAfter reset release, first sec remains 0 until 1Hz enable.");

        // Let run a bit more
        repeat (30) @(posedge clk);
        
        $display("\nTest completed.");
        $finish;
    end

endmodule
