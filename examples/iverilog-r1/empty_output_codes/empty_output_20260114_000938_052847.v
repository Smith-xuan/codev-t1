// Verilog code that resulted in empty output
// Saved at: 2026-01-14T00:09:38.052890
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

module DFF (Q, D, clk);
    output Q;
    input D, clk;
    
    // internal wires
    wire clk_bar;
    wire notD;
    
    wire master_SN, master_RN;
    wire master_Q, master_Qbar;
    wire q_master_bar;
    wire slave_SN, slave_RN;
    wire slave_Q, slave_Qbar;
    
    // internal logic
    // generate clk_bar (NOT clk)
    nand (clk_bar, clk, clk);
    
    // generate notD (NOT D)
    nand (notD, D, D);
    
    // master latch set/reset NAND gates (active low inputs)
    // master enable is low (clk_bar = 1 when clk=0)
    // master SN = ~(D & clk_bar) = NAND(D, clk_bar)
    nand (master_SN, D, clk_bar);
    // master RN = ~(notD & clk_bar) = NAND(notD, clk_bar)
    nand (master_RN, notD, clk_bar);
    
    // master cross-coupled NAND latch
    nand (master_Q, master_SN, master_Qbar);
    nand (master_Qbar, master_RN, master_Q);
    
    // generate complement of master_Q
    nand (q_master_bar, master_Q, master_Q);
    
    // slave latch set/reset NAND gates (active low inputs)
    // slave enable is high (clk = 1)
    // slave SN = ~(master_Q & clk) = NAND(master_Q, clk)
    nand (slave_SN, master_Q, clk);
    // slave RN = ~(q_master_bar & clk) = NAND(q_master_bar, clk)
    nand (slave_RN, q_master_bar, clk);
    
    // slave cross-coupled NAND latch
    nand (slave_Q, slave_SN, slave_Qbar);
    nand (slave_Qbar, slave_RN, slave_Q);
    
    // output assignment
    assign Q = slave_Q;
    
endmodule

module testbench;
    reg D, clk;
    wire Q;
    
    DFF dut (.Q(Q), .D(D), .clk(clk));
    
    // helper to check Q against expected at a given time
    task check;
        input expected;
        begin
            #1; // small delay for propagation
            if (Q !== expected) begin
                $display("ERROR at time %0d: Q = %b, expected %b", $time, Q, expected);
                $finish(1);
            end
        end
    endtask
    
    initial begin
        // Initialize
        D = 0;
        clk = 0;
        
        // Initialize flip-flop: set D=0 while clk=0, then clk=1 to lock
        #10 D = 0;
        #10 clk = 0; // ensure clk=0
        #20 clk = 1; // rising edge: master latch becomes opaque, holds D=0
        #10; // wait
        
        // Verify initial state Q=0
        if (Q !== 0) begin
            $display("ERROR: Initial Q not 0");
            $finish(1);
        end
        
        // Test 1: rising edge capture D=1
        D = 1;
        @(posedge clk); // next rising edge
        #1 check(1);
        $display("Test 1 passed: captured 1");
        
        // Test 2: D changes after rising edge, Q should not change
        #10 D = 0; // change D during high phase
        #10;
        if (Q !== 1) begin
            $display("ERROR: Q changed after rising edge while D changed");
            $finish(1);
        end
        $display("Test 2 passed: Q stable after rising edge");
        
        // Test 3: falling edge, D changes, Q should not change
        #10 clk = 0; // falling edge
        #10 D = 1;
        #10;
        if (Q !== 1) begin
            $display("ERROR: Q changed on falling edge");
            $finish(1);
        end
        $display("Test 3 passed: Q stable on falling edge");
        
        // Test 4: next rising edge capture D=1 (currently D=1)
        #10 clk = 1; // rising edge
        #1 check(1);
        $display("Test 4 passed: captured 1");
        
        // Test 5: next rising edge capture D=0
        #10 D = 0;
        #10 clk = 0; // falling edge
        #10 clk = 1; // rising edge
        #1 check(0);
        $display("Test 5 passed: captured 0");
        
        // Test 6: hold value
        #10 D = 1;
        #10 D = 0; // change D after rising edge while Q=0, then capture 1 later
        #10 clk = 0; // falling edge
        #10 D = 1; // set D to 1
        #10 clk = 1; // rising edge
        #1 check(1);
        $display("Test 6 passed: captured 1 after hold");
        
        $display("All tests passed!");
        #10 $finish;
    end
endmodule
