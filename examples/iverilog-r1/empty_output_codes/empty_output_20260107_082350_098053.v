// Verilog code that resulted in empty output
// Saved at: 2026-01-07T08:23:50.098101
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

module PC (
    input PCnewEnable,
    input bubble,
    input clk,
    input rst,
    input [31:0] PCnew,
    output reg [31:0] PC
);

always @(posedge clk) begin
    if (rst) begin
        PC <= 32'h00000000;
    end else if (PCnewEnable) begin
        PC <= PCnew;
    end else if (bubble) begin
        PC <= PC; // retain current value
    end else begin
        PC <= PC + 32'h00000004;
    end
end

endmodule

module testbench;
    reg PCnewEnable;
    reg bubble;
    reg clk;
    reg rst;
    reg [31:0] PCnew;
    wire [31:0] PC;
    
    PC dut (
        .PCnewEnable(PCnewEnable),
        .bubble(bubble),
        .clk(clk),
        .rst(rst),
        .PCnew(PCnew),
        .PC(PC)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        // Initialize
        PCnewEnable = 0;
        bubble = 0;
        rst = 0;
        PCnew = 0;
        
        // Test reset
        rst = 1;
        @(posedge clk);
        #1;
        if (PC !== 0) $stop;
        
        // Release reset, test increment
        rst = 0;
        @(posedge clk);
        #1;
        if (PC !== 4) $stop;
        
        // Test bubble
        bubble = 1;
        @(posedge clk);
        #1;
        if (PC !== 4) $stop;
        
        // Deassert bubble, increment
        bubble = 0;
        @(posedge clk);
        #1;
        if (PC !== 8) $stop;
        
        // Test PCnew load
        PCnew = 32'hABCD1234;
        PCnewEnable = 1;
        @(posedge clk);
        #1;
        if (PC !== 32'hABCD1234) $stop;
        
        // Test priority: bubble and PCnewEnable both high
        bubble = 1;
        PCnew = 32'hDEADBEEF;
        PCnewEnable = 1;
        @(posedge clk);
        #1;
        if (PC !== 32'hDEADBEEF) $stop;
        
        // Test overflow
        PCnew = 32'hFFFFFFFC;
        PCnewEnable = 1;
        @(posedge clk);
        #1;
        if (PC !== 32'hFFFFFFFC) $stop;
        PCnewEnable = 0;
        @(posedge clk);
        #1;
        if (PC !== 0) $stop; // wraps to 0
        @(posedge clk);
        #1;
        if (PC !== 4) $stop; // then increment to 4
        
        $display("All basic tests passed.");
        $finish;
    end
endmodule
