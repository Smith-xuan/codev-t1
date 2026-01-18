// Verilog code that resulted in empty output
// Saved at: 2026-01-14T21:29:59.942452
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

module rdesplazante (
    input CLK,
    input ENB,
    input DIR,
    input S_IN,
    input [1:0] MODE,
    input [3:0] D,
    output reg [3:0] Q,
    output reg S_OUT
);

always @(posedge CLK) begin
    if (ENB) begin
        case (MODE)
            2'b00: begin // shift
                if (DIR == 0) // left shift
                    Q <= {Q[2:0], S_IN};
                else // right shift
                    Q <= {S_IN, Q[3:1]};
            end
            2'b01: begin // rotate
                if (DIR == 0) // left rotate
                    Q <= {Q[2:0], Q[3]};
                else // right rotate
                    Q <= {Q[0], Q[3:1]};
            end
            2'b10: begin // parallel load
                Q <= D;
            end
            default: Q <= Q; // hold
        endcase
        // Update S_OUT only in shift mode
        if (MODE == 2'b00) begin
            if (DIR == 0) // left shift
                S_OUT <= Q[3];
            else // right shift
                S_OUT <= Q[0];
        end
        // else S_OUT remains unchanged (implicitly)
    end
end

endmodule

module testbench;
    reg CLK;
    reg ENB;
    reg DIR;
    reg S_IN;
    reg [1:0] MODE;
    reg [3:0] D;
    wire [3:0] Q;
    wire S_OUT;
    
    rdesplazante dut (
        .CLK(CLK),
        .ENB(ENB),
        .DIR(DIR),
        .S_IN(S_IN),
        .MODE(MODE),
        .D(D),
        .Q(Q),
        .S_OUT(S_OUT)
    );
    
    initial begin
        // Initialize signals
        CLK = 0;
        ENB = 0;
        DIR = 0;
        S_IN = 0;
        MODE = 2'b00;
        D = 4'h0;
        
        // Start with some known values
        #10;
        ENB = 1;
        
        // Test parallel load
        MODE = 2'b10;
        D = 4'b1010;
        @(posedge CLK);
        #1;
        $display("After parallel load: Q = %b, S_OUT = %b", Q, S_OUT);
        if (Q !== 4'b1010) $error("Parallel load failed: Q mismatch");
        
        // Test shift left (DIR=0)
        MODE = 2'b00;
        DIR = 0;
        S_IN = 1'b1;
        @(posedge CLK);
        #1;
        $display("After shift left with S_IN=1: Q = %b, S_OUT = %b", Q, S_OUT);
        // Expected: Q = old Q (1010) left shift -> {Q[2:0], S_IN} = {010, 1} = 0101.
        // Shifted-out bit is old Q[3] = 1, so S_OUT should be 1.
        if (Q !== 4'b0101) $error("Shift left failed: Q mismatch");
        if (S_OUT !== 1'b1) $error("Shift left S_OUT mismatch");
        
        // Another shift left with S_IN=0
        S_IN = 0;
        @(posedge CLK);
        #1;
        $display("After shift left with S_IN=0: Q = %b, S_OUT = %b", Q, S_OUT);
        // Current Q = 0101 -> left shift with S_IN=0: {101,0} = 1010.
        // Shifted-out bit is old Q[3] = 0.
        if (Q !== 4'b1010) $error("Shift left 2 failed");
        if (S_OUT !== 1'b0) $error("Shift left S_OUT 2 mismatch");
        
        // Test shift right (DIR=1)
        DIR = 1;
        S_IN = 1'b0;
        @(posedge CLK);
        #1;
        $display("After shift right with S_IN=0: Q = %b, S_OUT = %b", Q, S_OUT);
        // Current Q = 1010, shift right: {S_IN, Q[3:1]} = {0, 101} = 0101.
        // Shifted-out bit is old Q[0] = 0.
        if (Q !== 4'b0101) $error("Shift right failed");
        if (S_OUT !== 1'b0) $error("Shift right S_OUT mismatch");
        
        // Shift right again with S_IN=1
        S_IN = 1;
        @(posedge CLK);
        #1;
        $display("After shift right with S_IN=1: Q = %b, S_OUT = %b", Q, S_OUT);
        // Q = 0101 -> right shift: {1, 010} = 1010.
        // Shifted-out bit old Q[0] = 1.
        if (Q !== 4'b1010) $error("Shift right 2 failed");
        if (S_OUT !== 1'b1) $error("Shift right S_OUT 2 mismatch");
        
        // Test rotate left (DIR=0, MODE=01) from state 1010
        MODE = 2'b01;
        DIR = 0;
        @(posedge CLK);
        #1;
        $display("After rotate left: Q = %b, S_OUT = %b", Q, S_OUT);
        // Q = 1010 rotate left: {Q[2:0], Q[3]} = {010, 1} = 0101.
        // S_OUT not updated, should remain previous shifted-out bit (1 from shift right).
        if (Q !== 4'b0101) $error("Rotate left failed");
        // S_OUT should be unchanged (still 1)
        if (S_OUT !== 1'b1) $error("Rotate left S_OUT changed incorrectly");
        
        // Rotate right (DIR=1, MODE=01) from state 0101
        DIR = 1;
        @(posedge CLK);
        #1;
        $display("After rotate right: Q = %b, S_OUT = %b", Q, S_OUT);
        // Q = 0101 rotate right: {Q[0], Q[3:1]} = {1, 010}? Wait Q[3:1] = bits 3,2,1 = 0,1,0? Let's compute:
        // Q = 0101: Q[3]=0, Q[2]=1, Q[1]=0, Q[0]=1.
        // {Q[0], Q[3:1]} = {1, 0,1,0} = 1010.
        // So expected Q = 1010.
        if (Q !== 4'b1010) $error("Rotate right failed");
        // S_OUT unchanged (still 1)
        if (S_OUT !== 1'b1) $error("Rotate right S_OUT changed incorrectly");
        
        // Additional test: rotate left from 0101 (state now 1010 after rotate right)
        // Actually current state is 1010. Let's rotate left again.
        DIR = 0;
        @(posedge CLK);
        #1;
        $display("After another rotate left: Q = %b, S_OUT = %b", Q, S_OUT);
        // Q = 1010 rotate left: {010,1} = 0101.
        if (Q !== 4'b0101) $error("Rotate left 2 failed");
        
        // Test parallel load from any state
        MODE = 2'b10;
        D = 4'b1111;
        @(posedge CLK);
        #1;
        $display("After parallel load 1111: Q = %b, S_OUT = %b", Q, S_OUT);
        if (Q !== 4'b1111) $error("Parallel load 2 failed");
        // S_OUT unchanged (still 1)
        if (S_OUT !== 1'b1) $error("Parallel load S_OUT changed");
        
        // Test shift left from all ones with S_IN=0
        MODE = 2'b00;
        DIR = 0;
        S_IN = 0;
        @(posedge CLK);
        #1;
        $display("After shift left from 1111 with S_IN=0: Q = %b, S_OUT = %b", Q, S_OUT);
        // Q = 1111 left shift -> {111,0} = 1110.
        // Shifted-out bit old Q[3] = 1.
        if (Q !== 4'b1110) $error("Shift left from all ones failed");
        if (S_OUT !== 1'b1) $error("Shift left S_OUT from all ones mismatch");
        
        // Test shift right from all ones with S_IN=0
        DIR = 1;
        S_IN = 0;
        @(posedge CLK);
        #1;
        $display("After shift right from all ones with S_IN=0: Q = %b, S_OUT = %b", Q, S_OUT);
        // Q = 1110 right shift -> {0, 111} = 0111.
        // Shifted-out bit old Q[0] = 0 (since Q was 1110, LSB is 0).
        if (Q !== 4'b0111) $error("Shift right from all ones failed");
        if (S_OUT !== 1'b0) $error("Shift right S_OUT from all ones mismatch");
        
        $display("All tests passed!");
        $finish;
    end
endmodule
