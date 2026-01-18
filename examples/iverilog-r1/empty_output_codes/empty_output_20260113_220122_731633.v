// Verilog code that resulted in empty output
// Saved at: 2026-01-13T22:01:22.731666
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

module clock_divider (
    input clk,
    output divided_clk,
    output digit_clk
);

reg [19:0] counter_div = 0; // up to 600_000
reg [12:0] counter_digit = 0; // up to 5_000

reg divided_clk_reg = 0;
reg digit_clk_reg = 0;

always @(posedge clk) begin
    // divided_clk counter
    if (counter_div == 20'd600_000) begin
        counter_div <= 0;
        divided_clk_reg <= ~divided_clk_reg;
    end else begin
        counter_div <= counter_div + 1;
    end
    
    // digit_clk counter
    if (counter_digit == 13'd5_000) begin
        counter_digit <= 0;
        digit_clk_reg <= ~digit_clk_reg;
    end else begin
        counter_digit <= counter_digit + 1;
    end
end

assign divided_clk = divided_clk_reg;
assign digit_clk = digit_clk_reg;

endmodule

module testbench;
    reg clk;
    wire divided_clk;
    wire digit_clk;
    
    clock_divider dut (
        .clk(clk),
        .divided_clk(divided_clk),
        .digit_clk(digit_clk)
    );
    
    // Generate 100 MHz clock (period 10 ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Record toggle events
    integer last_div_toggle_time = 0;
    integer last_digit_toggle_time = 0;
    
    always @(posedge clk) begin
        if (dut.divided_clk_reg) begin
            // optional
        end
    end
    
    // Check toggles
    initial begin
        #100000; // 100 us
        $finish;
    end
endmodule
