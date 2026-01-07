// Verilog code that resulted in empty output
// Saved at: 2026-01-07T09:26:23.313256
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

`default_nettype none

module program_sequencer_Q9 (
    input clk,
    input sync_reset,
    input jmp,
    input jmp_nz,
    input dont_jmp,
    input [3:0] jmp_addr,
    output [9:0] pc_big,
    output [9:0] pm_address_big,
    output [7:0] from_PS
);

reg [9:0] pc_reg;

// Combinational next address logic
wire [9:0] jmp_shift6 = {jmp_addr, 6'b0};
wire [9:0] jmp_shift4 = {2'b0, jmp_addr, 4'b0};
wire [9:0] pc_inc = pc_reg + 1'b1;

wire [9:0] next_pm_address;
assign next_pm_address = sync_reset ? 10'b0 :
                         jmp ? jmp_shift6 :
                         (jmp_nz && !dont_jmp) ? jmp_shift4 :
                         pc_inc;

always @(posedge clk) begin
    pc_reg <= next_pm_address;
end

assign pc_big = pc_reg;
assign pm_address_big = next_pm_address;
assign from_PS = pc_reg[9:2];

endmodule

module testbench;
    reg clk;
    reg sync_reset;
    reg jmp;
    reg jmp_nz;
    reg dont_jmp;
    reg [3:0] jmp_addr;
    wire [9:0] pc_big;
    wire [9:0] pm_address_big;
    wire [7:0] from_PS;
    
    program_sequencer_Q9 dut (
        .clk(clk),
        .sync_reset(sync_reset),
        .jmp(jmp),
        .jmp_nz(jmp_nz),
        .dont_jmp(dont_jmp),
        .jmp_addr(jmp_addr),
        .pc_big(pc_big),
        .pm_address_big(pm_address_big),
        .from_PS(from_PS)
    );
    
    // Simple clock generation with limited cycles
    initial begin
        clk = 0;
        #100 $finish;
        forever begin
            #5 clk = ~clk;
        end
    end
    
    initial begin
        // Initialize inputs
        sync_reset = 0;
        jmp = 0;
        jmp_nz = 0;
        dont_jmp = 0;
        jmp_addr = 0;
        
        // Wait for first rising edge
        @(posedge clk);
        
        // Test 1: Reset
        $display("Test 1: Reset");
        sync_reset = 1;
        @(negedge clk);
        sync_reset = 0;
        if (pc_big !== 10'b0) begin
            $display("ERROR: pc_big after reset should be 0, got %b", pc_big);
            $finish;
        end
        if (pm_address_big !== 10'b0) begin
            $display("ERROR: pm_address_big after reset should be 0, got %b", pm_address_big);
            $finish;
        end
        $display("Test 1 passed");
        
        // Test 2: Sequential increment (3 cycles)
        $display("Test 2: Sequential increment");
        repeat (3) @(posedge clk);
        @(negedge clk);
        if (pc_big !== 3) begin
            $display("ERROR: After 3 increments, pc_big should be 3, got %0d", pc_big);
            $finish;
        end
        $display("Test 2 passed");
        
        // Test 3: Unconditional jump
        $display("Test 3: Unconditional jump");
        jmp = 1;
        jmp_addr = 4'b1010; // 10
        @(posedge clk);
        jmp = 0;
        @(negedge clk);
        if (pm_address_big !== {4'b1010, 6'b0}) begin
            $display("ERROR: pm_address_big after jump should be %b, got %b", {4'b1010, 6'b0}, pm_address_big);
            $finish;
        end
        @(posedge clk);
        @(negedge clk);
        if (pc_big !== {4'b1010, 6'b0}) begin
            $display("ERROR: pc_big after jump should be %b, got %b", {4'b1010, 6'b0}, pc_big);
            $finish;
        end
        $display("Test 3 passed");
        
        // Test 4: Conditional jump with dont_jmp low
        $display("Test 4: Conditional jump with dont_jmp low");
        jmp_nz = 1;
        dont_jmp = 0;
        jmp_addr = 4'b0011; // 3
        @(posedge clk);
        jmp_nz = 0;
        @(negedge clk);
        if (pm_address_big !== {2'b0, 4'b0011, 4'b0}) begin
            $display("ERROR: pm_address_big after conditional jump should be %b, got %b", {2'b0, 4'b0011, 4'b0}, pm_address_big);
            $finish;
        end
        @(posedge clk);
        @(negedge clk);
        if (pc_big !== {2'b0, 4'b0011, 4'b0}) begin
            $display("ERROR: pc_big after conditional jump should be %b, got %b", {2'b0, 4'b0011, 4'b0}, pc_big);
            $finish;
        end
        $display("Test 4 passed");
        
        // Test 5: Conditional jump with dont_jmp high (should not jump)
        $display("Test 5: Conditional jump with dont_jmp high");
        jmp_nz = 1;
        dont_jmp = 1;
        jmp_addr = 4'b1111; // 15
        @(posedge clk);
        jmp_nz = 0;
        dont_jmp = 0;
        @(negedge clk);
        // Should increment, not jump
        if (pc_big !== 49) begin // previous pc was 48 from test 4, plus increment
            $display("ERROR: pc_big should increment to 49, got %0d", pc_big);
            $finish;
        end
        $display("Test 5 passed");
        
        // Test 6: Priority: jump overrides conditional jump
        $display("Test 6: Priority test");
        jmp = 1;
        jmp_nz = 1;
        dont_jmp = 0;
        jmp_addr = 4'b0100; // 4
        @(posedge clk);
        jmp = 0;
        jmp_nz = 0;
        @(negedge clk);
        // Should jump (unconditional)
        if (pm_address_big !== {4'b0100, 6'b0}) begin
            $display("ERROR: unconditional jump should take precedence, got %b", pm_address_big);
            $finish;
        end
        $display("Test 6 passed");
        
        // Test 7: Reset during operation
        $display("Test 7: Reset during operation");
        sync_reset = 1;
        @(posedge clk);
        sync_reset = 0;
        @(negedge clk);
        if (pc_big !== 0) begin
            $display("ERROR: pc_big after reset should be 0, got %b", pc_big);
            $finish;
        end
        $display("Test 7 passed");
        
        // Test 8: Edge case max jmp_addr
        $display("Test 8: Max jump address");
        jmp = 1;
        jmp_addr = 4'b1111;
        @(posedge clk);
        jmp = 0;
        @(negedge clk);
        if (pm_address_big !== {4'b1111, 6'b0}) begin
            $display("ERROR: max jump failed, got %b", pm_address_big);
            $finish;
        end
        $display("Test 8 passed");
        
        // Test 9: Edge case max conditional jump
        $display("Test 9: Max conditional jump");
        jmp_nz = 1;
        dont_jmp = 0;
        jmp_addr = 4'b1111;
        @(posedge clk);
        jmp_nz = 0;
        @(negedge clk);
        if (pm_address_big !== {2'b0, 4'b1111, 4'b0}) begin
            $display("ERROR: max conditional jump failed, got %b", pm_address_big);
            $finish;
        end
        $display("Test 9 passed");
        
        $display("All tests passed!");
        $finish;
    end
endmodule
