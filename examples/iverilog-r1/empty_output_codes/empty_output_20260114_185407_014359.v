// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:54:07.014392
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

module sec_10 #(parameter PRESCALER_MAX = 25_000_000 - 1) (
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
            if (prescaler == PRESCALER_MAX) begin
                prescaler <= 0;
            end else begin
                prescaler <= prescaler + 1;
            end

            if (enable_1hz) begin
                if (sec == 9) begin
                    sec <= 0;
                end else begin
                    sec <= sec + 1;
                end
            end
        end
    end

    assign dout = (sec == 4'd0) ? 8'h3F :
                  (sec == 4'd1) ? 8'h06 :
                  (sec == 4'd2) ? 8'h5B :
                  (sec == 4'd3) ? 8'h4F :
                  (sec == 4'd4) ? 8'h66 :
                  (sec == 4'd5) ? 8'h6D :
                  (sec == 4'd6) ? 8'h7D :
                  (sec == 4'd7) ? 8'h07 :
                  (sec == 4'd8) ? 8'h7F :
                  8'h6F;

endmodule

module testbench;
    reg clk;
    reg reset;
    wire [7:0] dout;

    // Use a very small prescaler max for simulation
    sec_10 #(.PRESCALER_MAX(4)) dut (.clk(clk), .reset(reset), .dout(dout));

    initial begin
        clk = 0;
        reset = 1;
        // Apply reset for a few cycles
        repeat (3) begin
            #10 clk = ~clk;
        end
        reset = 0;
        // Let it run for many seconds
        repeat (100) begin
            @(posedge clk);
            $display("time=%0t: sec=%d, dout=%h", $time, dut.sec, dout);
        end
        // Test reset again
        reset = 1;
        repeat (2) @(posedge clk);
        reset = 0;
        @(posedge clk);
        $display("After reset: sec=%d, dout=%h", dut.sec, dout);
        // Run a few more cycles
        repeat (10) @(posedge clk);
        $finish;
    end
endmodule
