// Verilog code that resulted in empty output
// Saved at: 2026-01-14T23:37:26.808677
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

module altera_dual_port_ram_simple #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
) (
    input clk,
    input we,
    input [ADDR_WIDTH-1:0] w_addr,
    input [ADDR_WIDTH-1:0] r_addr,
    input [DATA_WIDTH-1:0] d,
    output [DATA_WIDTH-1:0] q
);
reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
reg [ADDR_WIDTH-1:0] r_addr_reg;

always @(posedge clk) begin
    r_addr_reg <= r_addr;
    if (we)
        mem[w_addr] <= d;
end

assign q = mem[r_addr_reg];
endmodule

module testbench;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 4; // small for testing
    reg clk;
    reg we;
    reg [ADDR_WIDTH-1:0] w_addr;
    reg [ADDR_WIDTH-1:0] r_addr;
    reg [DATA_WIDTH-1:0] d;
    wire [DATA_WIDTH-1:0] q;
    
    altera_dual_port_ram_simple #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .we(we),
        .w_addr(w_addr),
        .r_addr(r_addr),
        .d(d),
        .q(q)
    );
    
    initial begin
        clk = 0;
        we = 0;
        w_addr = 0;
        r_addr = 0;
        d = 0;
        #10;
        
        // Test 1: Write to address 5, then read from address 5
        @(posedge clk);
        we = 1;
        w_addr = 5;
        d = 32'hDEADBEEF;
        @(posedge clk);
        we = 0;
        r_addr = 5;
        #1; // wait a bit for combinational output
        if (q !== 32'hDEADBEEF) begin
            $display("ERROR: Test 1 failed. Expected DEADBEEF, got %h", q);
            $finish;
        end
        $display("Test 1 passed.");
        
        // Test 2: Write to address 2 while reading address 2 (same cycle)
        @(posedge clk);
        we = 1;
        w_addr = 2;
        r_addr = 2; // read address same as write address
        d = 32'h12345678;
        @(posedge clk);
        we = 0;
        // after clock edge, r_addr_reg becomes 2, output should be new data? let's check
        #1;
        // Since we wrote at posedge, the memory will be updated after the clock edge.
        // The output q is combinational from mem[r_addr_reg]. r_addr_reg became 2 at the clock edge.
        // mem[2] is updated with d after the clock edge (non-blocking assignment).
        // In simulation, mem[2] still holds old value (maybe unknown) because non-blocking assignment hasn't taken effect yet.
        // So q will be old value. That's read-old behavior.
        // Let's wait another clock edge.
        @(posedge clk);
        #1;
        if (q !== 32'h12345678) begin
            $display("ERROR: Test 2 failed. Expected 12345678, got %h", q);
            $finish;
        end
        $display("Test 2 passed.");
        
        // Test 3: Write to address 3, read from address 4 (different)
        @(posedge clk);
        we = 1;
        w_addr = 3;
        d = 32'hA5A5A5A5;
        r_addr = 4;
        @(posedge clk);
        we = 0;
        #1;
        // Expect unknown (or zero) at address 4 because never written.
        // Since memory initialized to unknown, we can't check exact value.
        // Instead, check that address 3 has correct data.
        r_addr = 3;
        #1;
        if (q !== 32'hA5A5A5A5) begin
            $display("ERROR: Test 3 failed. Expected A5A5A5A5, got %h", q);
            $finish;
        end
        $display("Test 3 passed.");
        
        // Test 4: Multiple writes and reads
        @(posedge clk);
        we = 1;
        w_addr = 0;
        d = 32'h11111111;
        r_addr = 0;
        @(posedge clk);
        we = 1;
        w_addr = 1;
        d = 32'h22222222;
        r_addr = 1;
        @(posedge clk);
        we = 1;
        w_addr = 2;
        d = 32'h33333333;
        r_addr = 2;
        @(posedge clk);
        we = 0;
        // Check all three addresses
        r_addr = 0;
        #1;
        if (q !== 32'h11111111) begin
            $display("ERROR: Test 4 address 0 failed.");
            $finish;
        end
        r_addr = 1;
        #1;
        if (q !== 32'h22222222) begin
            $display("ERROR: Test 4 address 1 failed.");
            $finish;
        end
        r_addr = 2;
        #1;
        if (q !== 32'h33333333) begin
            $display("ERROR: Test 4 address 2 failed.");
            $finish;
        end
        $display("Test 4 passed.");
        
        $display("All tests passed!");
        $finish;
    end
endmodule
