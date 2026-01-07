// Verilog code that resulted in empty output
// Saved at: 2026-01-06T13:34:31.782135
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

module one_pulse (
    input clk,
    input rst,
    input in_trig,
    output out_pulse
);

// Synchronizer (2 flip-flops) for metastability protection
reg [1:0] sync_reg;

// Edge detection register: previous synchronized value
reg trig_sync_prev;

// State definitions
localparam [1:0] IDLE   = 2'd0,
                 PULSE  = 2'd1,
                 LOCKED = 2'd2;

reg [1:0] state;  // Current state

always @(posedge clk) begin
    if (rst) begin
        // Reset clears all internal state
        sync_reg <= 2'b0;
        trig_sync_prev <= 1'b0;
        state <= IDLE;
    end else begin
        // Shift register synchronizer
        sync_reg <= {sync_reg[0], in_trig};
        // Capture previous synchronized value
        trig_sync_prev <= sync_reg[1];

        // State machine
        case (state)
            IDLE: begin
                // Rising edge on the synchronized signal
                if (~trig_sync_prev && sync_reg[1]) begin
                    state <= PULSE;  // Generate one-clock pulse
                end
            end
            PULSE: begin
                state <= LOCKED;  // After pulse, lock until signal goes low
            end
            LOCKED: begin
                // Wait for synchronized signal to go low before allowing another edge
                if (~sync_reg[1]) begin
                    state <= IDLE;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

// Output: pulse high only in PULSE state
assign out_pulse = (state == PULSE);

endmodule

module testbench;
    reg clk;
    reg rst;
    reg in_trig;
    wire out_pulse;

    one_pulse dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Initialize
        rst = 1;
        in_trig = 0;
        #20;
        rst = 0;
        #10;
        
        // Test single rising edge
        in_trig = 1;
        #50;
        in_trig = 0;
        #50;
        
        // Test rapid edges
        in_trig = 1;
        #5;
        in_trig = 0;
        #5;
        in_trig = 1;
        #5;
        in_trig = 0;
        #100;
        
        $finish;
    end
endmodule
