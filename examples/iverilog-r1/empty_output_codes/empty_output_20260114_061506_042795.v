// Verilog code that resulted in empty output
// Saved at: 2026-01-14T06:15:06.042829
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

// Dynamic pattern detector
module dyn_pattern_imp #(parameter BITS = 5) (
    input clk,
    input rst,
    input valid,
    input in,
    input [BITS-1:0] pattern,
    output reg out
);

    reg [BITS-1:0] buffer;
    reg [$clog2(BITS+1)-1:0] counter; // enough bits to hold 0..BITS

    wire [BITS-1:0] next_buffer = {buffer[BITS-2:0], in};
    wire [$clog2(BITS+1)-1:0] next_counter = (counter < BITS) ? counter + 1 : BITS;

    always @(posedge clk) begin
        if (rst) begin
            buffer <= {BITS{1'b0}};
            counter <= 0;
            out <= 0;
        end else begin
            if (valid) begin
                buffer <= next_buffer;
                // update counter
                counter <= next_counter;
                // check if we have full buffer
                if (next_counter == BITS) begin
                    if (next_buffer == pattern) begin
                        out <= 1;
                        counter <= 0; // reset for non-overlapping detection
                    end else begin
                        out <= 0;
                        counter <= next_counter - 1; // allow overlapping detection
                    end
                end else begin
                    out <= 0;
                end
            end else begin
                // when valid is low, keep out as 0 (or maybe hold? spec didn't say)
                out <= 0;
                // counter stays same
                // buffer stays same
            end
        end
    end

endmodule

// Testbench
module testbench;
    parameter BITS = 3;
    reg clk, rst, valid;
    reg in;
    reg [BITS-1:0] pattern;
    wire out;

    dyn_pattern_imp #(.BITS(BITS)) dut (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .in(in),
        .pattern(pattern),
        .out(out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Initialize
        rst = 1;
        valid = 0;
        in = 0;
        pattern = 3'b111;
        #10;
        rst = 0;
        #10;

        // Test sequence: input stream 111011111
        // Expected overlapping detection: pattern starts at positions 1,5,6,7 (assuming 1-indexed)
        // Let's convert to bits: bits 1-3=111, bits 5-7=111, bits 6-8=111, bits 7-9=111
        // In simulation we'll send bits one per clock with valid high.
        // We'll send 9 bits.
        // We'll wait for enough cycles to see detection.
        
        // Bit 1: 1
        valid = 1;
        in = 1;
        #10; // wait one clock cycle (posedge at time 10, 20, 30...)
        // Actually clock period is 10 units (5 high, 5 low). We'll wait 10 units to advance one cycle.
        // Let's use @(posedge clk) to synchronize.
        
        // Let's use procedural timing with clock edges.
        // I'll reset clock generation and use waits.
        // Let's restart test with better approach.
        $finish;
    end

endmodule
