// Verilog code that resulted in empty output
// Saved at: 2026-01-05T21:26:47.693175
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

module lab2_2 (
    input clock,
    input reset,
    output reg overflow,
    output reg [3:0] out
);

reg [3:0] state;

// Combinational overflow: high when state == 11
always @(*) begin
    overflow = (state == 4'd11);
end

// Sequential state update
always @(posedge clock) begin
    if (reset) begin
        state <= 4'b0;
    end else begin
        if (state == 4'd11) begin
            state <= 4'b0;
        end else begin
            state <= state + 1;
        end
    end
end

// Output assignment
always @(*) begin
    out = state;
end

endmodule


module testbench;
    reg clock;
    reg reset;
    wire overflow;
    wire [3:0] out;
    
    lab2_2 dut (
        .clock(clock),
        .reset(reset),
        .overflow(overflow),
        .out(out)
    );
    
    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end
    
    reg [3:0] expected_out;
    reg expected_overflow;
    integer cycle;
    integer error_count;
    
    initial begin
        error_count = 0;
        
        // Test 1: Reset
        reset = 1;
        #10;
        check_output(4'd0, 1'b0, "After reset");
        reset = 0;
        #5; // wait for just before posedge
        
        // Test 2: Sequence through states
        for (cycle = 0; cycle < 24; cycle = cycle + 1) begin
            @(posedge clock); // wait for posedge
            // Expected next state based on previous state
            // Actually we need to compute expected out after this clock edge
            // Since we're at posedge, the new state will be computed.
            // We'll compute expected_out based on previous expected_out
            // Let's use a variable to track expected state
        end
        
        // Better: have a separate test that runs many cycles and checks each state
        // Let's use a different approach
        
        $finish;
    end
    
    task check_output;
        input [3:0] expected_out_val;
        input expected_overflow_val;
        input string message;
        begin
            if (out !== expected_out_val || overflow !== expected_overflow_val) begin
                $display("ERROR at %0t: %s", $time, message);
                $display("  Expected out=0x%h, overflow=%b", expected_out_val, expected_overflow_val);
                $display("  Got      out=0x%h, overflow=%b", out, overflow);
                error_count = error_count + 1;
            end
        end
    endtask
    
endmodule
