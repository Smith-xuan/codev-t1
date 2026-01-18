// Verilog code that resulted in empty output
// Saved at: 2026-01-14T10:30:44.165827
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

module counter(
    input i_clk,
    output [6:0] o_debug
);

reg [32:0] counter_reg = 0;

always @(posedge i_clk) begin
    counter_reg <= counter_reg + 1;
end

assign o_debug = counter_reg[7:1];

endmodule

module testbench;
    reg i_clk;
    wire [6:0] o_debug;
    
    counter dut (.i_clk(i_clk), .o_debug(o_debug));
    
    reg [32:0] expected_counter;
    wire [6:0] expected_debug;
    
    initial begin
        i_clk = 0;
        expected_counter = 0;
    end
    
    always @(posedge i_clk) begin
        expected_counter <= expected_counter + 1;
    end
    
    assign expected_debug = (expected_counter >> 1) & 7'h7F;
    
    always @(posedge i_clk) begin
        #1; // wait a small delta to allow non-blocking updates
        if (o_debug !== expected_debug) begin
            $error("ERROR at time %0t: counter_reg = %h, o_debug = %b, expected = %b",
                   $time, dut.counter_reg, o_debug, expected_debug);
            $finish;
        end
    end
    
    initial begin
        // Generate clock
        forever #5 i_clk = ~i_clk;
    end
    
    initial begin
        // Run for many cycles
        #2000 $finish;
    end
endmodule
