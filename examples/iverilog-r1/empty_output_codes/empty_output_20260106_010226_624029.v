// Verilog code that resulted in empty output
// Saved at: 2026-01-06T01:02:26.624076
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

module sub(
    input clk,
    input rst,
    input [1:0] func,
    output reg out
);

    reg enable;

    always @(posedge clk) begin
        if (rst) begin
            enable <= 1'b0;
            out <= 1'b0;
        end else begin
            // enable: set to 1 when func == 1, otherwise retain
            if (func == 2'b01) begin
                enable <= 1'b1;
            end
            // else enable holds
            
            // out: set to 1 when func == 2 and enable (previous) is 1
            if (func == 2'b10) begin
                if (enable) begin
                    out <= 1'b1;
                end
            end
        end
    end

endmodule

module testbench;
    reg clk;
    reg rst;
    reg [1:0] func;
    wire out;
    
    sub dut (.clk(clk), .rst(rst), .func(func), .out(out));
    
    // simple clock
    initial begin
        clk = 0;
        #100 $finish;
    end
    
    always #5 clk = ~clk;
    
    initial begin
        // Test sequence
        rst = 1;
        func = 0;
        #10;
        if (dut.enable !== 0 || out !== 0) begin
            $display("FAIL1: reset");
            $finish;
        end
        
        rst = 0;
        #10;
        if (dut.enable !== 0 || out !== 0) begin
            $display("FAIL2: idle");
            $finish;
        end
        
        // func = 1
        func = 1;
        #10;
        if (dut.enable !== 1 || out !== 0) begin
            $display("FAIL3: func=1");
            $finish;
        end
        
        // func = 2
        func = 2;
        #10;
        if (dut.enable !== 1 || out !== 1) begin
            $display("FAIL4: func=2 with enable=1");
            $finish;
        end
        
        // func = 0
        func = 0;
        #10;
        if (dut.enable !== 1 || out !== 1) begin
            $display("FAIL5: func=0");
            $finish;
        end
        
        // func = 3
        func = 3;
        #10;
        if (dut.enable !== 1 || out !== 1) begin
            $display("FAIL6: func=3");
            $finish;
        end
        
        // Reset
        rst = 1;
        #10;
        if (dut.enable !== 0 || out !== 0) begin
            $display("FAIL7: reset while high");
            $finish;
        end
        
        // After reset, func=1, then func=2 with enable low after reset
        rst = 0;
        func = 1;
        #10;
        // now enable=1, out=0
        func = 2;
        #10;
        // out should become 1 because enable was high during previous cycle
        if (out !== 1) begin
            $display("FAIL8: out not set when enable was high");
            $finish;
        end
        
        // Now enable high, out high
        // func = 1 again (should stay high)
        func = 1;
        #10;
        if (dut.enable !== 1 || out !== 1) begin
            $display("FAIL9: double func=1");
            $finish;
        end
        
        // func = 0 to clear enable? Actually enable holds.
        func = 0;
        #10;
        // enable stays 1, out stays 1
        
        $display("All tests passed!");
        $finish;
    end
endmodule
