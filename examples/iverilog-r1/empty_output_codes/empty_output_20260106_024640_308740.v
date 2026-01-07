// Verilog code that resulted in empty output
// Saved at: 2026-01-06T02:46:40.308777
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

`timescale 1ns/1ps

module debounce (
    input clk,
    input ibutton,
    output reg obutton
);
    reg [31:0] shift_reg;
    
    // Initialize for simulation
    initial begin
        shift_reg = 32'b0;
        obutton = 1'b0;
    end
    
    always @(posedge clk) begin
        shift_reg <= {shift_reg[30:0], ibutton};
        
        // Update output based on shift register contents
        if (shift_reg == 32'hFFFFFFFF) begin
            obutton <= 1'b1;
        end else if (shift_reg == 32'h0) begin
            obutton <= 1'b0;
        end
    end
endmodule

module testbench;
    reg clk;
    reg ibutton;
    wire obutton;
    
    debounce dut (.clk(clk), .ibutton(ibutton), .obutton(obutton));
    
    // Clock generation
    initial begin
        clk = 0;
        repeat (500) #5 clk = ~clk;
        $finish;
    end
    
    // Stimulus
    initial begin
        ibutton = 0;
        // Wait a bit
        #100;
        
        // Test stable low
        ibutton = 0;
        #1000;
        if (obutton !== 1'b0) begin
            $display("FAIL: obutton should be 0, got %b", obutton);
            $finish;
        end
        
        // Test stable high
        ibutton = 1;
        #1024; // enough cycles
        if (obutton !== 1'b1) begin
            $display("FAIL: obutton should be 1, got %b", obutton);
            $finish;
        end
        
        // Test bounce
        ibutton = 0;
        #8;
        ibutton = 1;
        #8;
        ibutton = 0;
        #8;
        ibutton = 1;
        #8;
        ibutton = 0;
        #1024;
        if (obutton !== 1'b0) begin
            $display("FAIL: obutton should be 0 after bounce, got %b", obutton);
            $finish;
        end
        
        // Test rapid toggling
        ibutton = 1;
        #100;
        ibutton = 0;
        #100;
        ibutton = 1;
        #100;
        if (obutton !== 1'b1) begin
            $display("FAIL: obutton should stay 1, got %b", obutton);
            $finish;
        end
        
        $display("All tests passed");
        $finish;
    end
endmodule
