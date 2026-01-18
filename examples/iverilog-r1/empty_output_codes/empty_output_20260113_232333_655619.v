// Verilog code that resulted in empty output
// Saved at: 2026-01-13T23:23:33.655654
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

module tick_gen(
    input clk,
    input rstN,
    output reg oTick1ms
);

// For a 50 MHz clock, 1 ms period = 50,000 cycles
// Counter counts from 0 to 49999 (inclusive)
parameter COUNT_MAX = 50000; // Actually 49999 if we count from 0
localparam COUNTER_WIDTH = $clog2(COUNT_MAX);
reg [COUNTER_WIDTH-1:0] counter;

always @(posedge clk or negedge rstN) begin
    if (!rstN) begin
        counter <= 0;
        oTick1ms <= 0;
    end else begin
        // Default tick to 0
        oTick1ms <= 0;
        
        // Check if counter has reached max
        if (counter == COUNT_MAX - 1) begin
            // Generate tick for one cycle
            oTick1ms <= 1;
            // Reset counter to 0
            counter <= 0;
        end else begin
            // Increment counter
            counter <= counter + 1;
        end
    end
end

endmodule

// Testbench
module testbench;
    reg clk;
    reg rstN;
    wire oTick1ms;
    
    // Instantiate DUT
    tick_gen dut (
        .clk(clk),
        .rstN(rstN),
        .oTick1ms(oTick1ms)
    );
    
    // Clock generation: 50 MHz (20 ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20 ns period => 50 MHz
    end
    
    // Stimulus
    initial begin
        // Initialize
        rstN = 0;
        
        // Apply reset for a few cycles
        #20;
        rstN = 1;
        
        // Wait for some ticks (should see tick every 1 ms)
        // Let's wait for 5 ms (5 cycles of tick)
        #5000; // 5 ms
        
        // Apply reset again
        rstN = 0;
        #20;
        rstN = 1;
        
        // Wait a bit more
        #2000;
        
        $finish;
    end
    
    // Monitoring
    integer tick_count = 0;
    integer last_tick_time = 0;
    realtime tick_period;
    
    always @(posedge clk) begin
        if (oTick1ms) begin
            tick_count = tick_count + 1;
            if (tick_count == 1) begin
                last_tick_time = $time;
            end else begin
                tick_period = $time - last_tick_time;
                last_tick_time = $time;
                $display("Tick %0d at time %0t ns, period since last tick = %0t ns", 
                         tick_count, $time, tick_period);
            end
        end
    end
    
    // Final check
    initial begin
        #60000; // Wait longer to ensure enough ticks
        $display("Simulation finished.");
        $finish;
    end
endmodule
