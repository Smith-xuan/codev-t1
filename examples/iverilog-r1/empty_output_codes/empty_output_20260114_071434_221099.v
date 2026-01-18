// Verilog code that resulted in empty output
// Saved at: 2026-01-14T07:14:34.221135
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

module debounce (
    input D_in,
    input clk_in,
    input reset,
    output D_out
);
    reg [9:0] shift_reg;

    always @(posedge clk_in) begin
        if (reset)
            shift_reg <= 10'b0;
        else
            shift_reg <= {shift_reg[8:0], D_in};
    end

    assign D_out = ~shift_reg[9] & (& shift_reg[8:0]);
endmodule

module testbench;
    reg D_in;
    reg clk_in;
    reg reset;
    wire D_out;

    debounce dut (
        .D_in(D_in),
        .clk_in(clk_in),
        .reset(reset),
        .D_out(D_out)
    );

    initial begin
        // Initialize inputs
        D_in = 0;
        clk_in = 0;
        reset = 1;

        // Apply reset
        @(posedge clk_in);
        reset <= 0;
        @(posedge clk_in);
        // Now start test sequence

        // Test 1: Input stays low for 10 cycles
        $display("Test 1: Input stays low");
        repeat(10) begin
            D_in = 0;
            @(posedge clk_in);
            $display("  clock %0d: D_in=%b, shift_reg=%b, D_out=%b", $time, D_in, dut.shift_reg, D_out);
        end

        // Test 2: Input goes high for 10 cycles, then low for one cycle
        $display("\nTest 2: Input high for 10 cycles then low");
        repeat(10) begin
            D_in = 1;
            @(posedge clk_in);
            $display("  clock %0d: D_in=%b, shift_reg=%b, D_out=%b", $time, D_in, dut.shift_reg, D_out);
        end
        D_in = 0;
        @(posedge clk_in);
        $display("  clock %0d: D_in=%b, shift_reg=%b, D_out=%b", $time, D_in, dut.shift_reg, D_out);
        @(posedge clk_in);
        $display("  clock %0d: D_in=%b, shift_reg=%b, D_out=%b", $time, D_in, dut.shift_reg, D_out);

        // Test 3: Input random sequence
        $display("\nTest 3: Random sequence");
        D_in = 1;
        @(posedge clk_in);
        D_in = 0;
        @(posedge clk_in);
        D_in = 1;
        @(posedge clk_in);
        D_in = 1;
        @(posedge clk_in);
        D_in = 0;
        @(posedge clk_in);
        D_in = 1;
        @(posedge clk_in);
        D_in = 1;
        @(posedge clk_in);
        D_in = 1;
        @(posedge clk_in);
        D_in = 1;
        @(posedge clk_in);
        D_in = 1;
        @(posedge clk_in);
        $display("  clock %0d: D_in=%b, shift_reg=%b, D_out=%b", $time, D_in, dut.shift_reg, D_out);
        // Wait more to see pattern
        repeat(5) @(posedge clk_in);
        $finish;
    end

endmodule
