// Verilog code that resulted in empty output
// Saved at: 2026-01-14T07:13:56.120971
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

module blinker #(
    parameter real CLK_FREQ = 50_000_000, // default 50 MHz
    parameter real PERIOD = 1.0 // default 1 second period
) (
    input rstb,
    input clk,
    output out
);

    // compute half period in clock cycles
    localparam real HALF_PERIOD_REAL = CLK_FREQ * PERIOD / 2.0;
    localparam integer HALF_PERIOD = $rtoi(HALF_PERIOD_REAL);
    
    // counter width: enough bits to count up to HALF_PERIOD-1
    localparam integer COUNTER_WIDTH = (HALF_PERIOD <= 1) ? 1 : $clog2(HALF_PERIOD);
    
    reg [COUNTER_WIDTH-1:0] count = 0;
    reg out_reg = 0;
    
    assign out = out_reg;
    
    always @(posedge clk) begin
        if (!rstb) begin
            count <= 0;
            out_reg <= 0;
        end else begin
            if (count == HALF_PERIOD - 1) begin
                count <= 0;
                out_reg <= ~out_reg;
            end else begin
                count <= count + 1;
            end
        end
    end
    
endmodule

module testbench;
    reg rstb;
    reg clk;
    wire out;
    
    // Use scaled parameters for simulation
    blinker #(
        .CLK_FREQ(10.0), // 10 Hz clock
        .PERIOD(0.2)     // period = 0.2 seconds => half period = 1 clock cycle
    ) dut (
        .rstb(rstb),
        .clk(clk),
        .out(out)
    );
    
    initial begin
        clk = 0;
        rstb = 0;
        // Hold reset for a few cycles
        #20;
        rstb = 1;
        // Run for some cycles
        #200;
        $finish;
    end
    
    always #5 clk = ~clk;
    
endmodule
