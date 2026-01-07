// Verilog code that resulted in empty output
// Saved at: 2026-01-06T06:05:44.379683
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

module sort(
    input en,
    input [3:0] a1, a2, a3, a4, a5,
    output reg [3:0] o1, o2, o3, o4, o5
);

    // Internal array for bubble sort
    reg [3:0] arr [0:4];
    integer i, j;
    
    always @(posedge en) begin
        // Load inputs into array
        arr[0] <= a1;
        arr[1] <= a2;
        arr[2] <= a3;
        arr[3] <= a4;
        arr[4] <= a5;
        
        // Bubble sort descending
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4 - i; j = j + 1) begin
                if (arr[j] < arr[j+1]) begin
                    // Swap
                    arr[j] <= arr[j+1];
                    arr[j+1] <= arr[j];
                end
            end
        end
        
        // Map outputs: largest to smallest
        o5 <= arr[0];
        o4 <= arr[1];
        o3 <= arr[2];
        o2 <= arr[3];
        o1 <= arr[4];
    end

endmodule

module testbench;
    reg en;
    reg [3:0] a1, a2, a3, a4, a5;
    wire [3:0] o1, o2, o3, o4, o5;
    
    sort dut (en, a1, a2, a3, a4, a5, o1, o2, o3, o4, o5);
    
    initial begin
        // Initialize
        en = 0;
        a1 = 0; a2 = 0; a3 = 0; a4 = 0; a5 = 0;
        
        // Test case 1: random values
        #10;
        @(posedge en);
        #1;
        en = 1;
        #10;
        en = 0;
        #10;
        a1 = 4'h3;
        a2 = 4'h8;
        a3 = 4'h1;
        a4 = 4'h5;
        a5 = 4'h2;
        
        // Pulse enable
        @(posedge en);
        #1;
        en = 1;
        #10;
        en = 0;
        #10;
        // Expected sorted descending: 8,5,3,2,1 => o5=8, o4=5, o3=3, o2=2, o1=1
        $display("Test 1: a=%h,%h,%h,%h,%h", a1, a2, a3, a4, a5);
        $display("  o5 (largest) = %h (expected 8)", o5);
        $display("  o4 = %h (expected 5)", o4);
        $display("  o3 = %h (expected 3)", o3);
        $display("  o2 = %h (expected 2)", o2);
        $display("  o1 = %h (expected 1)", o1);
        if (o5 !== 4'h8 || o4 !== 4'h5 || o3 !== 4'h3 || o2 !== 4'h2 || o1 !== 4'h1) begin
            $display("ERROR: Test 1 failed!");
        end
        
        // Test case 2: all same values
        #10;
        a1 = 4'h5;
        a2 = 4'h5;
        a3 = 4'h5;
        a4 = 4'h5;
        a5 = 4'h5;
        @(posedge en);
        #1;
        en = 1;
        #10;
        en = 0;
        #10;
        $display("Test 2: all same values");
        $display("  o5 = %h (expected 5)", o5);
        $display("  o4 = %h (expected 5)", o4);
        $display("  o3 = %h (expected 5)", o3);
        $display("  o2 = %h (expected 5)", o2);
        $display("  o1 = %h (expected 5)", o1);
        if (o5 !== 4'h5 || o4 !== 4'h5 || o3 !== 4'h5 || o2 !== 4'h5 || o1 !== 4'h5) begin
            $display("ERROR: Test 2 failed!");
        end
        
        // Test case 3: ascending order
        #10;
        a1 = 4'h1;
        a2 = 4'h2;
        a3 = 4'h3;
        a4 = 4'h4;
        a5 = 4'h5;
        @(posedge en);
        #1;
        en = 1;
        #10;
        en = 0;
        #10;
        $display("Test 3: ascending input");
        $display("  o5 = %h (expected 5)", o5);
        $display("  o4 = %h (expected 4)", o4);
        $display("  o3 = %h (expected 3)", o3);
        $display("  o2 = %h (expected 2)", o2);
        $display("  o1 = %h (expected 1)", o1);
        if (o5 !== 4'h5 || o4 !== 4'h4 || o3 !== 4'h3 || o2 !== 4'h2 || o1 !== 4'h1) begin
            $display("ERROR: Test 3 failed!");
        end
        
        // Test case 4: descending order (already sorted)
        #10;
        a1 = 4'h5;
        a2 = 4'h4;
        a3 = 4'h3;
        a4 = 4'h2;
        a5 = 4'h1;
        @(posedge en);
        #1;
        en = 1;
        #10;
        en = 0;
        #10;
        $display("Test 4: descending input");
        $display("  o5 = %h (expected 5)", o5);
        $display("  o4 = %h (expected 4)", o4);
        $display("  o3 = %h (expected 3)", o3);
        $display("  o2 = %h (expected 2)", o2);
        $display("  o1 = %h (expected 1)", o1);
        if (o5 !== 4'h5 || o4 !== 4'h4 || o3 !== 4'h3 || o2 !== 4'h2 || o1 !== 4'h1) begin
            $display("ERROR: Test 4 failed!");
        end
        
        // Test case 5: negative numbers (4-bit signed, but we treat as unsigned)
        #10;
        a1 = 4'hF;  // 15
        a2 = 4'hC;  // 12
        a3 = 4'h0;  // 0
        a4 = 4'hA;  // 10
        a5 = 4'h7;  // 7
        @(posedge en);
        #1;
        en = 1;
        #10;
        en = 0;
        #10;
        $display("Test 5: mixed values");
        $display("  o5 = %h (expected F)", o5);
        $display("  o4 = %h (expected F? Actually largest is F (15), next is A (10), then C (12), then 7 (7), then 0 (0))", o4);
        // Wait need to compute: inputs: F(15), C(12), 0(0), A(10), 7(7). Sorted descending: F, C, A, 7, 0.
        // So expected: o5=F, o4=C, o3=A, o2=7, o1=0.
        $display("  o4 = %h (expected C)", o4);
        $display("  o3 = %h (expected A)", o3);
        $display("  o2 = %h (expected 7)", o2);
        $display("  o1 = %h (expected 0)", o1);
        if (o5 !== 4'hF || o4 !== 4'hC || o3 !== 4'hA || o2 !== 4'h7 || o1 !== 4'h0) begin
            $display("ERROR: Test 5 failed!");
        end
        
        // Test case 6: maximum values
        #10;
        a1 = 4'hF;
        a2 = 4'hF;
        a3 = 4'hF;
        a4 = 4'hF;
        a5 = 4'hE;
        @(posedge en);
        #1;
        en = 1;
        #10;
        en = 0;
        #10;
        $display("Test 6: max values");
        $display("  o5 = %h (expected F)", o5);
        $display("  o4 = %h (expected F)", o4);
        $display("  o3 = %h (expected F)", o3);
        $display("  o2 = %h (expected F)", o2);
        $display("  o1 = %h (expected E)", o1);
        if (o5 !== 4'hF || o4 !== 4'hF || o3 !== 4'hF || o2 !== 4'hF || o1 !== 4'hE) begin
            $display("ERROR: Test 6 failed!");
        end
        
        $display("All tests completed.");
        $finish;
    end
endmodule
