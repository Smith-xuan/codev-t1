// Verilog code that resulted in empty output
// Saved at: 2026-01-15T03:01:43.452986
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

module led (
    input rst_n,
    input clk,
    input led_in,
    output reg led0,
    output reg led1,
    output reg led2,
    output reg led3
);

always @(posedge clk) begin
    if (!rst_n) begin
        led0 <= 1'b0;
        led1 <= 1'b0;
        led2 <= 1'b0;
        led3 <= 1'b0;
    end else begin
        if (led_in) begin
            led0 <= 1'b1;
            led1 <= 1'b1;
            led2 <= 1'b1;
            led3 <= 1'b1;
        end else begin
            led0 <= 1'b0;
            led1 <= 1'b0;
            led2 <= 1'b0;
            led3 <= 1'b0;
        end
    end
end

endmodule

module testbench;
    reg rst_n;
    reg clk;
    reg led_in;
    wire led0, led1, led2, led3;
    
    led dut (
        .rst_n(rst_n),
        .clk(clk),
        .led_in(led_in),
        .led0(led0),
        .led1(led1),
        .led2(led2),
        .led3(led3)
    );
    
    initial begin
        clk = 0;
        rst_n = 1;
        led_in = 0;
        
        // Test reset active (low)
        @(negedge clk);
        rst_n = 0;
        led_in = 1; // led_in high while reset should override
        @(posedge clk);
        #1; // wait for propagation
        if (led0 !== 0 || led1 !== 0 || led2 !== 0 || led3 !== 0) begin
            $display("ERROR: Reset active but LEDs not all off!");
            $finish;
        end
        $display("Reset test passed.");
        
        // Release reset, led_in low => LEDs off
        @(negedge clk);
        rst_n = 1;
        led_in = 0;
        @(posedge clk);
        #1;
        if (led0 !== 0 || led1 !== 0 || led2 !== 0 || led3 !== 0) begin
            $display("ERROR: After reset release, led_in low but LEDs not off!");
            $finish;
        end
        $display("LEDs off after reset release with led_in low passed.");
        
        // led_in high => LEDs on
        @(negedge clk);
        led_in = 1;
        @(posedge clk);
        #1;
        if (led0 !== 1 || led1 !== 1 || led2 !== 1 || led3 !== 1) begin
            $display("ERROR: led_in high but LEDs not all on!");
            $finish;
        end
        $display("LEDs all on passed.");
        
        // Switch led_in low again, ensure they turn off on next clock edge
        @(negedge clk);
        led_in = 0;
        @(posedge clk);
        #1;
        if (led0 !== 0 || led1 !== 0 || led2 !== 0 || led3 !== 0) begin
            $display("ERROR: led_in low but LEDs not off again!");
            $finish;
        end
        $display("LEDs turn off again passed.");
        
        // Test reset while LEDs are on
        @(negedge clk);
        rst_n = 0;
        @(posedge clk);
        #1;
        if (led0 !== 0 || led1 !== 0 || led2 !== 0 || led3 !== 0) begin
            $display("ERROR: Reset while LEDs on did not turn them off!");
            $finish;
        end
        $display("Reset works while LEDs on passed.");
        
        $display("All tests passed!");
        $finish;
    end
endmodule
