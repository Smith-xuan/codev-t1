// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:07:32.539119
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
localparam ZERO = 2'b00;
localparam DET_1 = 2'b01;
localparam DET_10 = 2'b10;
localparam DET_101 = 2'b11;

reg [1:0] current_state, next_state;

// State register with active-low reset
always @(posedge clock or negedge reset) begin
    if (!reset) begin
        current_state <= ZERO;
    end else begin
        current_state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (current_state)
        ZERO: begin
            if (data == 1'b1)
                next_state = DET_1;
            else
                next_state = ZERO;
        end
        DET_1: begin
            if (data == 1'b0)
                next_state = DET_10;
            else
                next_state = DET_1; // data == 1
        end
        DET_10: begin
            if (data == 1'b1)
                next_state = DET_101;
            else
                next_state = ZERO; // data == 0
        end
        DET_101: begin
            if (data == 1'b1)
                next_state = DET_1;
            else
                next_state = DET_10; // data == 0
        end
        default: next_state = ZERO;
    endcase
end

// Output logic
assign detected_101 = (current_state == DET_101);

endmodule

module testbench;
    reg clock;
    reg reset;
    reg data;
    wire detected_101;
    
    seq_det_101_fsm dut (.clock(clock), .reset(reset), .data(data), .detected_101(detected_101));
    
    initial begin
        clock = 0;
        reset = 0;
        data = 0;
        #100 $finish;
    end
    
    always #5 clock = ~clock;
    
endmodule
