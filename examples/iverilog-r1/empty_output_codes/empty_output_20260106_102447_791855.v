// Verilog code that resulted in empty output
// Saved at: 2026-01-06T10:24:47.791900
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

module top_module (
    input clk,
    input resetn,
    input in,
    output out
);
    reg [3:0] shift_reg;
    
    always @(posedge clk) begin
        if (!resetn) begin
            shift_reg <= 4'b0;
        end else begin
            shift_reg <= {shift_reg[2:0], in};
        end
    end
    
    assign out = shift_reg[3];
endmodule

module testbench;
    reg clk;
    reg resetn;
    reg in;
    wire out;
    
    top_module dut (
        .clk(clk),
        .resetn(resetn),
        .in(in),
        .out(out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Stimulus
    initial begin
        // Initialize
        resetn = 1;
        in = 0;
        
        // Reset (active low)
        #2 resetn = 0;
        #10 resetn = 1;
        
        // Test sequence
        // After reset, shift_reg = 0000, out = 0
        // Shift in 'in' values: 1, 0, 1, 1
        in = 1; @(posedge clk);
        in = 0; @(posedge clk);
        in = 1; @(posedge clk);
        in = 1; @(posedge clk);
        
        // Wait one more cycle to see final output
        @(posedge clk);
        
        // Check final output: after shifting four bits 1,0,1,1, the MSB should be the first bit (1) ?
        // Let's compute: start 0000
        // cycle1: shift in 1 => 0001, out=0
        // cycle2: shift in 0 => 0010, out=0
        // cycle3: shift in 1 => 0101, out=0
        // cycle4: shift in 1 => 1010, out=1? Wait shift left: 0101 becomes 101? Actually 4-bit: 0101 << 1 = 1010, with LSB new bit =1 => 1011? No, we do {shift_reg[2:0], in}. shift_reg = 0101, shift_reg[2:0] = 101, in=1 => 1011. Let's recalc:
        // Let's do systematic.
        
        // We'll instead have the testbench compute expected values.
        // But first, we need to reconsider simulation: we applied in before posedge and changed after posedge, but we need to ensure in is stable at posedge.
        // Better to use non-blocking assignments.
        // Let's restart simulation with proper stimulus.
        $finish;
    end
endmodule
