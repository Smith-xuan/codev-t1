// Verilog code that resulted in empty output
// Saved at: 2026-01-15T02:37:35.948782
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

module pwm(
    input clk,
    output [3:0] led
);
    reg [7:0] counter = 0;
    always @(posedge clk) begin
        if (counter == 8'd100)
            counter <= 8'd0;
        else
            counter <= counter + 1;
    end
    assign led[0] = (counter < 8'd20);
    assign led[1] = (counter < 8'd40);
    assign led[2] = (counter < 8'd60);
    assign led[3] = (counter < 8'd80);
endmodule

module testbench;
    reg clk;
    wire [3:0] led;
    
    pwm uut (.clk(clk), .led(led));
    
    integer i;
    integer on_count0, on_count1, on_count2, on_count3;
    integer total_cycles;
    
    initial begin
        clk = 0;
        on_count0 = 0;
        on_count1 = 0;
        on_count2 = 0;
        on_count3 = 0;
        total_cycles = 0;
        
        // Wait for initial clock to get counter started
        @(posedge clk);
        
        // Monitor for two full periods
        repeat (2) begin
            // Wait for counter to wrap around? Actually we'll count cycles until counter returns to 0.
            // But we can just count 101 cycles per period.
            repeat (101) begin
                @(posedge clk);
                // Count cycles
                total_cycles = total_cycles + 1;
                // Count on cycles for each LED
                if (led[0]) on_count0 = on_count0 + 1;
                if (led[1]) on_count1 = on_count1 + 1;
                if (led[2]) on_count2 = on_count2 + 1;
                if (led[3]) on_count3 = on_count3 + 1;
            end
        end
        
        // Report statistics
        $display("Period statistics:");
        $display("  Total cycles per period: %0d", 101);
        $display("  LED0 on cycles: %0d, duty cycle: %0.3f%%", on_count0, (on_count0 * 100.0) / 101.0);
        $display("  LED1 on cycles: %0d, duty cycle: %0.3f%%", on_count1, (on_count1 * 100.0) / 101.0);
        $display("  LED2 on cycles: %0d, duty cycle: %0.3f%%", on_count2, (on_count2 * 100.0) / 101.0);
        $display("  LED3 on cycles: %0d, duty cycle: %0.3f%%", on_count3, (on_count3 * 100.0) / 101.0);
        
        // Also print some waveform for visual inspection
        $display("\nCounter and LED values for first few cycles:");
        for (i = 0; i < 15; i = i + 1) begin
            @(posedge clk);
            $display("  Counter = %0d, led = %b", uut.counter, led);
        end
        
        $finish;
    end
endmodule
