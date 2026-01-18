// Verilog code that resulted in empty output
// Saved at: 2026-01-14T12:24:46.725076
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

module VGA_Counter (
    input i_Clk,
    output reg [9:0] o_Col_Count,
    output reg [9:0] o_Row_Count
);

always @(posedge i_Clk) begin
    if (o_Col_Count == 10'd799) begin
        o_Col_Count <= 10'd0;
        if (o_Row_Count == 10'd524)
            o_Row_Count <= 10'd0;
        else
            o_Row_Count <= o_Row_Count + 1;
    end else begin
        o_Col_Count <= o_Col_Count + 1;
    end
end

initial begin
    o_Col_Count = 10'd0;
    o_Row_Count = 10'd0;
end

endmodule

module testbench;
    reg clk;
    wire [9:0] col, row;
    
    VGA_Counter dut (
        .i_Clk(clk),
        .o_Col_Count(col),
        .o_Row_Count(row)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        #100000; // simulate for 100,000 time units
        $finish;
    end
    
    always #5 clk = ~clk;
    
    // Checker variables
    integer cycle_count;
    reg [9:0] expected_col, expected_row;
    integer error_count;
    
    initial begin
        cycle_count = 0;
        error_count = 0;
    end
    
    // Monitor on each posedge clk (after a small delay)
    always @(posedge clk) begin
        #1; // wait a little after clock edge
        
        // Increment cycle count (this clock edge is counted)
        cycle_count = cycle_count + 1;
        
        // Compute expected values based on cycle count
        // After N clock edges, column = N, row = floor(N/800)
        expected_col = cycle_count % 800;
        expected_row = (cycle_count / 800) % 525;
        
        // Compare
        if (col !== expected_col || row !== expected_row) begin
            $display("ERROR at cycle %0d: expected col=%0d row=%0d, got col=%0d row=%0d",
                     cycle_count, expected_col, expected_row, col, row);
            error_count = error_count + 1;
            if (error_count > 10) begin
                $display("Too many errors, stopping simulation.");
                $finish;
            end
        end
        
    end
    
    // Additional corner case tests
    initial begin
        // Wait for initial conditions
        #10;
        
        // Test 1: Check initial state (should be 0,0)
        #40; // wait until after first posedge?
        // Actually we can check now at time 10 (after 1 posedge at time 5?)
        // Not needed for correctness as the primary test already runs.
    end
    
endmodule
