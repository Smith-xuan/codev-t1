// Verilog code that resulted in empty output
// Saved at: 2026-01-05T20:28:56.260428
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

module counter_refresh(
    input clk_400Hz,
    output reg [2:0] select
);

initial select = 3'b000;

always @(posedge clk_400Hz) begin
    select <= (select == 3'b111) ? 3'b000 : select + 1;
end

endmodule

module testbench;
    reg clk_400Hz;
    wire [2:0] select;
    
    counter_refresh dut(clk_400Hz, select);
    
    initial begin
        clk_400Hz = 0;
        // Generate 20 half cycles (10 full cycles)
        repeat(20) #1 clk_400Hz = ~clk_400Hz;
        $finish;
    end
    
    integer errors;
    initial begin
        errors = 0;
        // Wait for first posedge
        @(posedge clk_400Hz);
        // Check select is 0 (initialized)
        if (select !== 3'b000) begin
            $display("ERROR: Expected 0, got %b", select);
            errors = errors + 1;
        end
        
        // Now each subsequent posedge should increment
        @(posedge clk_400Hz);
        if (select !== 3'b001) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b010) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b011) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b100) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b101) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b110) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b111) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b000) errors = errors + 1;
        @(posedge clk_400Hz);
        if (select !== 3'b001) errors = errors + 1;
        
        // After 8 more edges, should be back to 0
        @(posedge clk_400Hz);
        @(posedge clk_400Hz);
        @(posedge clk_400Hz);
        @(posedge clk_400Hz);
        if (select !== 3'b000) errors = errors + 1;
        
        // Also check that select does not change on negative edges
        begin
            reg [2:0] val_at_negedge;
            @(negedge clk_400Hz);
            val_at_negedge = select;
            #1;
            if (select !== val_at_negedge) errors = errors + 1;
        end
        
        if (errors == 0) $display("SUCCESS: All tests passed.");
        else $display("FAILURE: %0d errors.", errors);
    end
endmodule
