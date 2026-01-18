// Verilog code that resulted in empty output
// Saved at: 2026-01-14T10:17:47.131232
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

module synchronizer #(
    parameter DATA_WIDTH = 1,
    parameter DELAY_NUM = 1
) (
    input clk,
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout
);

generate
    if (DELAY_NUM == 0) begin
        assign dout = din;
    end else begin
        // Shift register implementation
        reg [DATA_WIDTH-1:0] shift_reg [0:DELAY_NUM-1];
        always @(posedge clk) begin
            // Shift data through pipeline
            for (integer i = DELAY_NUM-1; i > 0; i = i - 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end
            shift_reg[0] <= din;
        end
        assign dout = shift_reg[DELAY_NUM-1];
    end
endgenerate

endmodule

module testbench;
    // Test non-zero delay
    parameter DATA_WIDTH = 8;
    parameter DELAY_NUM = 2;
    
    reg clk;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;
    
    synchronizer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DELAY_NUM(DELAY_NUM)
    ) dut (
        .clk(clk),
        .din(din),
        .dout(dout)
    );
    
    // Expected reference model
    reg [DATA_WIDTH-1:0] expected [0:10];
    integer cycle_count;
    
    initial begin
        clk = 0;
        cycle_count = 0;
        // Initialize expected values to unknown
        for (integer i = 0; i <= 10; i = i + 1) expected[i] = 'x;
        
        // Apply test sequence
        din = 8'h00;
        @(posedge clk);
        cycle_count = cycle_count + 1;
        expected[0] = din;
        
        // Sequence of values
        repeat (20) begin
            din = cycle_count;
            @(posedge clk);
            cycle_count = cycle_count + 1;
            expected[cycle_count-1] = din;
        end
        
        // Wait for pipeline to propagate
        repeat (10) @(posedge clk);
        
        $display("Test finished without errors");
        $finish;
    end
    
    // Checker at negedge
    always @(negedge clk) begin
        // Wait a small delay to ensure values are stable after NBA updates
        #1;
        // For cycles after pipeline is filled, compare dout with expected
        // We can compare starting from cycle DELAY_NUM+1
        if (cycle_count >= DELAY_NUM + 1) begin
            if (dout !== expected[cycle_count - DELAY_NUM]) begin
                $display("ERROR at cycle %0d: dout=%h, expected=%h", 
                         cycle_count - DELAY_NUM, dout, expected[cycle_count - DELAY_NUM]);
                $finish(1);
            end else begin
                $display("Cycle %0d: din=%h, dout=%h, expected=%h OK",
                         cycle_count - DELAY_NUM, expected[cycle_count - DELAY_NUM], dout, expected[cycle_count - DELAY_NUM]);
            end
        end
    end
endmodule
