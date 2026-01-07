// Verilog code that resulted in empty output
// Saved at: 2026-01-06T23:51:25.360790
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

module vertical_counter(
    input clk_25MHz,
    input enable_V_Counter,
    output reg [15:0] V_Count_Value
);

initial V_Count_Value = 16'd0;

always @(posedge clk_25MHz) begin
    if (enable_V_Counter) begin
        if (V_Count_Value == 16'd524)
            V_Count_Value <= 16'd0;
        else
            V_Count_Value <= V_Count_Value + 1'b1;
    end
end

endmodule

module testbench;
    reg clk_25MHz;
    reg enable_V_Counter;
    wire [15:0] V_Count_Value;
    
    vertical_counter dut (
        .clk_25MHz(clk_25MHz),
        .enable_V_Counter(enable_V_Counter),
        .V_Count_Value(V_Count_Value)
    );
    
    // Clock generation: 25 MHz => period 40 ns
    initial begin
        clk_25MHz = 0;
        repeat (100) #20 clk_25MHz = ~clk_25MHz; // generate 50 edges
        $finish;
    end
    
    // Test procedure
    initial begin
        // Initialize inputs
        enable_V_Counter = 0;
        
        // Wait for initial value to set (initial block)
        #1;
        
        // Check initial value
        if (V_Count_Value !== 16'd0) begin
            $display("ERROR: Initial count not 0, got %d", V_Count_Value);
            $finish;
        end
        
        // Test enable low: count should stay at 0 for 10 clocks
        repeat (10) @(posedge clk_25MHz);
        if (V_Count_Value !== 16'd0) begin
            $display("ERROR: Count changed while enable low, got %d", V_Count_Value);
            $finish;
        end
        
        // Test enable high: increment each clock up to 524 then wrap
        enable_V_Counter = 1;
        
        // Count forward and check each value
        for (integer i = 0; i <= 525; i = i + 1) begin
            @(posedge clk_25MHz);
            // Expected count: for i from 0 to 524, count = i; for i = 525, count = 0 (wrap)
            if (i < 525) begin
                if (V_Count_Value !== i) begin
                    $display("ERROR at cycle %d: expected %d, got %d", i, i, V_Count_Value);
                    $finish;
                end
            end else begin
                if (V_Count_Value !== 0) begin
                    $display("ERROR at wrap cycle: expected 0, got %d", V_Count_Value);
                    $finish;
                end
            end
        end
        
        // Continue counting a few more to ensure wrap works
        repeat (5) @(posedge clk_25MHz);
        // Check that after wrap we get 1,2,3,4,5
        // Actually after wrap at cycle 525, count became 0. Then each subsequent clock increments.
        // We already have 5 extra clocks, so count should be 5.
        if (V_Count_Value !== 5) begin
            $display("ERROR: After wrap sequence, expected 5, got %d", V_Count_Value);
            $finish;
        end
        
        // Test enable low again
        enable_V_Counter = 0;
        repeat (5) @(posedge clk_25MHz);
        if (V_Count_Value !== 5) begin
            $display("ERROR: Count changed while enable low, got %d", V_Count_Value);
            $finish;
        end
        
        // Test enable high again to continue counting
        enable_V_Counter = 1;
        @(posedge clk_25MHz);
        if (V_Count_Value !== 6) begin
            $display("ERROR: Expected 6 got %d", V_Count_Value);
            $finish;
        end
        
        $display("All tests passed!");
        $finish;
    end
    
endmodule
