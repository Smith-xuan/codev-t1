// Verilog code that resulted in empty output
// Saved at: 2026-01-14T14:13:50.052819
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

module JK_FF (
    input J,
    input K,
    input clk,
    output reg Q,
    output Qn
);
    assign Qn = ~Q;
    always @(posedge clk) begin
        case ({J, K})
            2'b00: ; // hold
            2'b01: Q <= 1'b0; // reset
            2'b10: Q <= 1'b1; // set
            2'b11: Q <= ~Q; // toggle
        endcase
    end
endmodule

module testbench;
    reg J, K, clk;
    wire Q, Qn;
    
    JK_FF dut (.J(J), .K(K), .clk(clk), .Q(Q), .Qn(Qn));
    
    initial begin
        // Initialize
        J = 0;
        K = 0;
        clk = 0;
        
        // Test case 1: Hold (J=0, K=0)
        @(negedge clk);
        J = 0; K = 0;
        clk = 1;
        @(negedge clk);
        clk = 0;
        // Check that Q remains unchanged (should be X initially)
        $display("Test 1: Hold - J=%b, K=%b, Q=%b, Qn=%b", J, K, Q, Qn);
        
        // Test case 2: Reset (J=0, K=1)
        @(negedge clk);
        J = 0; K = 1;
        clk = 1;
        @(negedge clk);
        clk = 0;
        $display("Test 2: Reset - J=%b, K=%b, Q=%b, Qn=%b", J, K, Q, Qn);
        
        // Test case 3: Set (J=1, K=0)
        @(negedge clk);
        J = 1; K = 0;
        clk = 1;
        @(negedge clk);
        clk = 0;
        $display("Test 3: Set - J=%b, K=%b, Q=%b, Qn=%b", J, K, Q, Qn);
        
        // Test case 4: Toggle (J=1, K=1) - need to know current Q to predict
        // Let's test toggle from 1 to 0
        @(negedge clk);
        J = 1; K = 1;
        clk = 1;
        @(negedge clk);
        clk = 0;
        $display("Test 4: Toggle 1 -> 0 - J=%b, K=%b, Q=%b, Qn=%b", J, K, Q, Qn);
        // Now toggle again from 0 to 1
        @(negedge clk);
        J = 1; K = 1;
        clk = 1;
        @(negedge clk);
        clk = 0;
        $display("Test 5: Toggle 0 -> 1 - J=%b, K=%b, Q=%b, Qn=%b", J, K, Q, Qn);
        
        // Additional edge cases: hold after reset
        @(negedge clk);
        J = 0; K = 0;
        clk = 1;
        @(negedge clk);
        clk = 0;
        $display("Test 6: Hold after reset - J=%b, K=%b, Q=%b, Qn=%b", J, K, Q, Qn);
        
        $finish;
    end
endmodule
