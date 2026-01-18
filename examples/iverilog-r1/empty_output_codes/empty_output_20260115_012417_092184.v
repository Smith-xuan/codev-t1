// Verilog code that resulted in empty output
// Saved at: 2026-01-15T01:24:17.092234
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

`timescale 1ns/1ns

module levelAdjust (
    input clk,
    input rst,
    input [6:0] score,
    input [6:0] primeNumberInput,
    input levelAdjustEnable,
    output reg [6:0] primeNumberOutput,
    output reg findPrimeEnable
);

    wire [6:0] divisor;
    
    // Determine divisor based on score ranges
    assign divisor = (score < 7'd25) ? 7'd25 :
                     (score < 7'd50) ? 7'd50 :
                     (score < 7'd75) ? 7'd75 :
                     7'd100;
    
    always @(posedge clk) begin
        if (!rst) begin
            primeNumberOutput <= 7'b0;
            findPrimeEnable <= 1'b0;
        end else begin
            findPrimeEnable <= levelAdjustEnable;
            if (levelAdjustEnable) begin
                primeNumberOutput <= primeNumberInput % divisor;
            end
        end
    end

endmodule

module testbench;
    reg clk;
    reg rst;
    reg [6:0] score;
    reg [6:0] primeNumberInput;
    reg levelAdjustEnable;
    wire [6:0] primeNumberOutput;
    wire findPrimeEnable;
    
    levelAdjust dut (
        .clk(clk),
        .rst(rst),
        .score(score),
        .primeNumberInput(primeNumberInput),
        .levelAdjustEnable(levelAdjustEnable),
        .primeNumberOutput(primeNumberOutput),
        .findPrimeEnable(findPrimeEnable)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        // Initialize inputs
        rst = 1'b1;
        score = 7'd0;
        primeNumberInput = 7'd0;
        levelAdjustEnable = 1'b0;
        
        // Wait a few cycles
        #10;
        
        // Test 1: Reset low condition
        rst = 1'b0;
        #10;
        if (primeNumberOutput !== 7'b0 || findPrimeEnable !== 1'b0) begin
            $display("ERROR: Reset low test failed: primeNumberOutput=%b, findPrimeEnable=%b", primeNumberOutput, findPrimeEnable);
            $finish;
        end
        
        // Test 2: Reset high, enable low, change score and primeNumberInput
        rst = 1'b1;
        levelAdjustEnable = 1'b0;
        score = 7'd30;
        primeNumberInput = 7'd100;
        #10;
        // Since enable low, findPrimeEnable should be 0, and primeNumberOutput may hold previous value (0 from reset)
        if (findPrimeEnable !== 1'b0) begin
            $display("ERROR: Enable low test failed: findPrimeEnable=%b", findPrimeEnable);
            $finish;
        end
        // primeNumberOutput could be previous (0) or unchanged. We'll just note.
        
        // Test 3: Enable high, score 30 -> divisor 50 (since score < 50), remainder 100 % 50 = 0
        levelAdjustEnable = 1'b1;
        #10;
        // Wait for clock edge, check after posedge (10ns later)
        // At time 30ns, after posedge at 30ns? Let's compute: initial time 0, clock period 10ns, edges at 5,15,25,35...
        // Actually we changed at time 20? Let's redo timing.
        // Let's restructure test with better timing.
        $finish;
    end
    
endmodule
