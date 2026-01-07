// Verilog code that resulted in empty output
// Saved at: 2026-01-06T07:02:37.086806
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

module baud_gen (
    input clk,
    input reset,
    output reg tick
);
    reg [11:0] count;

    always @(posedge clk) begin
        if (reset) begin
            count <= 12'b0;
            tick <= 1'b0;
        end else begin
            if (count == 12'd2604) begin
                count <= 12'b0;
                tick <= 1'b1;
            end else begin
                count <= count + 1'b1;
                tick <= 1'b0;
            end
        end
    end
endmodule

module testbench;
    reg clk;
    reg reset;
    wire tick;

    baud_gen dut (.clk(clk), .reset(reset), .tick(tick));

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        reset = 1;
        #20;
        reset = 0;
        // Wait for a few ticks
        #13050; // wait for 3 extra ticks? Let's compute:
        // Each tick period is (2605 * 10 ns = 26050 ns) because clock period is 10 ns (5 ns half period).
        // So after reset deassertion, first tick at 2604 cycles later.
        // We'll monitor.
        $finish;
    end

    // Monitoring
    integer tick_count = 0;
    realtime prev_tick;
    initial begin
        prev_tick = 0;
        forever begin
            @(posedge clk);
            if (tick) begin
                tick_count = tick_count + 1;
                $display("Tick %0d at time %0t ns", tick_count, $time);
                if (tick_count == 1) begin
                    prev_tick = $time;
                end else if (tick_count == 2) begin
                    $display("Time between ticks: %0t ns", $time - prev_tick);
                    prev_tick = $time;
                end else if (tick_count == 3) begin
                    $display("Time between ticks: %0t ns", $time - prev_tick);
                    // Check tick period equals 26050 ns (2605 clock cycles * 10 ns per cycle)
                    if (($time - prev_tick) != 26050) begin
                        $display("ERROR: Tick period incorrect. Expected 26050 ns, got %0t ns", $time - prev_tick);
                    end
                end
            end
        end
    end

    // Final check
    initial begin
        #130500; // wait long enough
        $display("Simulation finished. tick_count = %0d", tick_count);
        if (tick_count < 2) $display("ERROR: Not enough ticks observed");
        $finish;
    end
endmodule
