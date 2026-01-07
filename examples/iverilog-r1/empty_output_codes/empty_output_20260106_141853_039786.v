// Verilog code that resulted in empty output
// Saved at: 2026-01-06T14:18:53.039814
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

module timer_2 #(parameter WIDTH = 26) (
    input wire clk,
    input wire rst,
    output wire true
);

reg [WIDTH-1:0] counter;

always @(posedge clk) begin
    if (rst) begin
        counter <= {WIDTH{1'b0}};
    end else begin
        counter <= counter + 1;
    end
end

assign true = (counter == {WIDTH{1'b1}});  // all ones

endmodule

module testbench;
    // Instantiate with small width for testing
    localparam TEST_WIDTH = 3;
    reg clk;
    reg rst;
    wire true_out;
    
    timer_2 #(.WIDTH(TEST_WIDTH)) dut (.clk(clk), .rst(rst), .true(true_out));
    
    // Clock generation with finite cycles
    initial begin
        clk = 0;
        // Generate 50 clock cycles
        for (integer i = 0; i < 50; i = i + 1) begin
            #5 clk = ~clk;
        end
    end
    
    initial begin
        // Initialize
        rst = 1;
        // Wait for first posedge to apply reset
        @(posedge clk);
        // Check counter is zero after reset
        #1; // slight delay after clock edge
        if (dut.counter !== {TEST_WIDTH{1'b0}}) begin
            $error("Counter not zero after reset");
            $finish;
        end
        if (true_out !== 1'b0) begin
            $error("True should be 0 at counter 0");
            $finish;
        end
        
        // Deassert reset
        rst = 0;
        
        // Let it count a few cycles
        #30; // 3 cycles
        // Counter should be 3
        if (dut.counter !== {TEST_WIDTH{1'b0}} + 3) begin
            $error("Counter not incrementing correctly");
            $finish;
        end
        
        // Count up to max-1, then check true is 0
        // We'll let it count until near max, but with small width we can reach max quickly.
        // Let's force counter to max-1
        force dut.counter = {TEST_WIDTH{1'b1}} - 1;
        #1;
        if (true_out !== 1'b0) begin
            $error("True should be 0 at max-1 counter");
            $finish;
        end
        
        // Force counter to max, check true is 1
        force dut.counter = {TEST_WIDTH{1'b1}};
        #1;
        if (true_out !== 1'b1) begin
            $error("True should be 1 at max counter");
            $finish;
        end
        
        // Release force, let it increment one cycle
        release dut.counter;
        @(posedge clk);
        #1;
        // Counter should wrap to 0, true should be 0
        if (dut.counter !== {TEST_WIDTH{1'b0}}) begin
            $error("Counter should wrap to zero after max");
            $finish;
        end
        if (true_out !== 1'b0) begin
            $error("True should be 0 after wrap");
            $finish;
        end
        
        // Second reset test
        rst = 1;
        @(posedge clk);
        #1;
        if (dut.counter !== {TEST_WIDTH{1'b0}}) begin
            $error("Counter not zero after second reset");
            $finish;
        end
        
        // Test that true only high when counter is exactly max for one cycle
        // We'll run a few full cycles to verify
        rst = 0;
        // Wait for a full cycle where true becomes 1
        // Since small width, max is 7. We count cycles until we see true high.
        // We'll run for several full cycles (20 cycles) and check that true pulses correctly.
        for (integer cycle = 0; cycle < 20; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            // Check that true is high only when counter == max
            if (dut.counter == {TEST_WIDTH{1'b1}} && true_out !== 1'b1) begin
                $error("True should be 1 at max counter cycle %0d", cycle);
                $finish;
            end
            if (dut.counter != {TEST_WIDTH{1'b1}} && true_out !== 1'b0) begin
                $error("True should be 0 when counter not max cycle %0d", cycle);
                $finish;
            end
        end
        
        // All tests passed
        $display("All tests passed for width %0d", TEST_WIDTH);
        #10 $finish;
    end
    
endmodule
