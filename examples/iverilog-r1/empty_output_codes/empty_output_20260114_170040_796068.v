// Verilog code that resulted in empty output
// Saved at: 2026-01-14T17:00:40.796122
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

module multest(
    input clock,
    output [7:0] out
);
    reg [7:0] counter = 0;
    wire [15:0] square;

    always @(posedge clock) begin
        counter <= counter + 1;
    end

    assign square = counter * counter;
    assign out = square[7:0];
endmodule

module testbench;
    reg clock;
    wire [7:0] out;
    
    multest dut (.clock(clock), .out(out));
    
    initial begin
        clock = 0;
        // Generate clock
        forever #5 clock = ~clock;
    end
    
    initial begin
        // Wait for a few cycles
        #300;
        $finish;
    end
    
    // Automated checking
    integer i;
    initial begin
        // Wait for initial value
        #1; // small delay to avoid race
        // Check at each posedge clock
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clock);
            // Compute expected out
            // out = (counter * counter) mod 256
            // Note: counter is i after increment? Actually at posedge, counter has already incremented.
            // Let's compute based on current counter value.
            // We'll compute after a small delay after posedge to stabilize.
            #1;
            if (out !== (dut.counter * dut.counter) % 256) begin
                $error("Mismatch at counter=%0d, out=%0d, expected=%0d", 
                       dut.counter, out, (dut.counter * dut.counter) % 256);
                $finish;
            end
        end
        $display("All checks passed for 0-255.");
        #100;
        $finish;
    end
endmodule
