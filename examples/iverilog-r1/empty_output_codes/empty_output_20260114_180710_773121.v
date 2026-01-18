// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:07:10.773148
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

module seq_det_101_fsm (
    input clock,
    input reset,
    input data,
    output detected_101
);

    // State definitions
    localparam [1:0] ZERO    = 2'b00;
    localparam [1:0] DET_1   = 2'b01;
    localparam [1:0] DET_10  = 2'b10;
    localparam [1:0] DET_101 = 2'b11;

    reg [1:0] state, next_state;

    // State register
    always @(posedge clock) begin
        if (!reset) begin
            state <= ZERO;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            ZERO: begin
                if (data) next_state = DET_1;
                else next_state = ZERO;
            end
            DET_1: begin
                if (data) next_state = DET_1;
                else next_state = DET_10;
            end
            DET_10: begin
                if (data) next_state = DET_101;
                else next_state = ZERO;
            end
            DET_101: begin
                if (data) next_state = DET_1;
                else next_state = DET_10;
            end
            default: next_state = ZERO;
        endcase
    end

    // Output logic (Moore)
    assign detected_101 = (state == DET_101);

endmodule

module testbench;
    reg clock;
    reg reset;
    reg data;
    wire detected_101;

    seq_det_101_fsm dut (
        .clock(clock),
        .reset(reset),
        .data(data),
        .detected_101(detected_101)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // Reference model for sequence detection (overlapping)
    function reference_detection;
        input [1:0] ref_state;
        input ref_data;
        // This reference model should mimic the FSM behavior.
        // Actually we can compute expected output based on the FSM.
        // Since we have a model, we can compute expected detection.
        // We'll store expected detection in an array.
    endfunction

    // Test sequence: random bits for 32 cycles
    reg [31:0] test_bits;
    integer i;
    reg expected_detected;
    reg [1:0] expected_state;

    initial begin
        // Seed for repeatable results
        test_bits = 32'b10101010101010101010101010101010; // pattern that contains many '101'
        #10;
        reset = 1'b1;
        @(negedge clock); // wait for negedge to apply data before posedge
        for (i = 0; i < 32; i = i + 1) begin
            data = test_bits[i];
            @(posedge clock);
            // Wait a small delay for signals to settle
            #1;
            // Compute expected state and detection based on our FSM model
            // We'll implement a model that mimics the FSM.
            // Actually we can compute expected state using the same transitions.
            // Let's compute expected next state and detection.
            // At this point, we have already clocked, so the state in dut is the state after the edge.
            // We need to compute what the state should be given the input at this cycle.
            // Actually we need to think: The expected detection is the detection that should have occurred at the previous cycle.
            // Because our FSM detection is delayed by one cycle.
            // Let's instead compute expected detection for the window that ended at this cycle.
            // We'll keep a queue of last 3 bits.
        end
        #10 $finish;
    end

endmodule
