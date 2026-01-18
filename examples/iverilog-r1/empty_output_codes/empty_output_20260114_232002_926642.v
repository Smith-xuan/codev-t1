// Verilog code that resulted in empty output
// Saved at: 2026-01-14T23:20:02.926718
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

module jk_ff (
    input clk,
    input rst_n,
    input j,
    input k,
    output reg q
);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q <= 1'b0;
    end else begin
        case ({j,k})
            2'b00: q <= q;
            2'b01: q <= 1'b0;
            2'b10: q <= 1'b1;
            2'b11: q <= ~q;
        endcase
    end
end
endmodule

module mealy_1101_jk (
    input x,
    input clk,
    input rst,
    output y
);
    // State bits: q1 is MSB, q0 is LSB
    reg q1, q0;
    wire [1:0] state = {q1, q0};
    
    // Next state signals
    wire n1, n0;
    // n1 = (~q1 & q0 & x) | (q1 & ~q0)
    assign n1 = (~q1 & q0 & x) | (q1 & ~q0);
    // n0 = (~q1 & ~q0 & x) | (q1 & ~q0 & ~x) | (q1 & q0 & x)
    assign n0 = (~q1 & ~q0 & x) | (q1 & ~q0 & ~x) | (q1 & q0 & x);
    
    // JK inputs
    wire j1 = n1;
    wire k1 = q1 & ~n1;
    
    wire j0 = n0;
    wire k0 = q0 & ~n0;
    
    // Output (Mealy) - high when state is S3 (11) and input completes sequence
    assign y = (state == 2'b11) && x;
    
    // Instantiate JK flip-flops with active-low reset
    jk_ff ff1 (.clk(clk), .rst_n(rst), .j(j1), .k(k1), .q(q1));
    jk_ff ff0 (.clk(clk), .rst_n(rst), .j(j0), .k(k0), .q(q0));
endmodule

module testbench;
    reg x, clk, rst;
    wire y;
    
    mealy_1101_jk dut (x, clk, rst, y);
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Stimulus
    initial begin
        rst = 0;
        x = 0;
        
        // Release reset after 10 time units
        #10 rst = 1;
        
        // Test sequence 1101
        // Align with rising edge at time 15? Let's wait for rising edge at 15
        #5; // time 15
        x = 1; // bit 1
        #10; // wait for next rising edge at 25? Actually clock edges: 0,5,10,15,20,25...
        // At time 15, x changed. At rising edge at 20? Let's compute.
        // Better to change x at falling edge before rising edge.
        // Let's do simple: at each 10 units, we change x.
        // We'll just run for 10 clock cycles.
    end
    
    initial begin
        #200 $finish;
    end
endmodule
