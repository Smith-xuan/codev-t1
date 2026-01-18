// Verilog code that resulted in empty output
// Saved at: 2026-01-14T16:33:17.925040
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

module pix_ticker (
    input clk,
    input reset,
    output reg tick
);

parameter MAX_TICK = 208334;
reg [17:0] counter;

always @(posedge clk) begin
    if (reset) begin
        counter <= 0;
        tick <= 0;
    end else begin
        if (counter == MAX_TICK) begin
            counter <= 0;
            tick <= 1;
        end else begin
            counter <= counter + 1;
            tick <= 0;
        end
    end
end

endmodule

module testbench;
    reg clk;
    reg reset;
    wire tick;
    
    pix_ticker dut (.clk(clk), .reset(reset), .tick(tick));
    
    // Generate clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        reset = 1;
        #10 reset = 0;
        #1000000 $finish;
    end
    
    // Monitor
    integer cycle_count = 0;
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (reset) begin
            if (cycle_count > 0) $display("Cycle %0d: Reset active", cycle_count);
        end else begin
            if (dut.counter == 208334) begin
                $display("Cycle %0d: Counter == MAX, tick = %0d", cycle_count, tick);
            end
        end
    end
endmodule
