// Verilog code that resulted in empty output
// Saved at: 2026-01-06T08:33:31.479392
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

module clk_make (
    input wire clk,
    input wire rst,
    output reg baud_clk
);
    parameter DIVIDE = 250;   // division factor
    parameter COUNTER_WIDTH = $clog2(DIVIDE); // width to count 0 to DIVIDE-1
    reg [COUNTER_WIDTH-1:0] counter;
    
    always @(posedge clk) begin
        if (rst) begin
            counter <= 0;
            baud_clk <= 0;
        end else begin
            // Toggle when counter reaches division factor minus one
            if (counter == DIVIDE - 1) begin
                counter <= 0;
                baud_clk <= ~baud_clk;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule

module testbench;
    reg clk;
    reg rst;
    wire baud_clk;
    
    clk_make dut (.clk(clk), .rst(rst), .baud_clk(baud_clk));
    
    // Generate 125 MHz clock (period 8 ns)
    always #4 clk = ~clk;
    
    integer cycle_count;
    real baud_period, baud_freq;
    real prev_edge_time;
    integer edge_count;
    
    initial begin
        clk = 0;
        rst = 1;
        cycle_count = 0;
        edge_count = 0;
        prev_edge_time = 0;
        
        // Apply reset
        @(posedge clk);
        rst <= 0;
        
        // Wait for some edges
        #100; // some time
        
        // Measure period of baud_clk
        wait (baud_clk === 1'bx); // wait for first posedge? Actually baud_clk may be unknown initially but after reset it's 0.
        // Instead, wait for any edge
        @(posedge baud_clk);
        prev_edge_time = $time;
        @(negedge baud_clk);
        prev_edge_time = $time;
        @(posedge baud_clk);
        baud_period = $time - prev_edge_time;
        baud_freq = 1_000_000_000.0 / baud_period; // Hz
        $display("Baud clock period = %0.3f ns, frequency = %0.3f Hz", baud_period, baud_freq);
        
        // Check frequency
        if (baud_freq > 499000 && baud_freq < 501000) begin
            $display("PASS: Baud frequency within 500 kHz +/- 1 kHz");
        end else begin
            $display("FAIL: Expected ~500 kHz, got %0.3f kHz", baud_freq / 1000.0);
        end
        
        $finish;
    end
    
    // Monitor cycles
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 2000) $finish;
    end
endmodule
