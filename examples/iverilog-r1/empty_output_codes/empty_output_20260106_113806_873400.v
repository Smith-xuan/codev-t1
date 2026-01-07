// Verilog code that resulted in empty output
// Saved at: 2026-01-06T11:38:06.873424
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

`timescale 1ns / 1ps

module ButtonDebouncer #(
    parameter DELAY_THRESHOLD = 454545
) (
    input wire clk,
    input wire signal,
    output reg debounced
);

    // FSM states
    localparam [1:0] IDLE     = 2'b00;
    localparam [1:0] PRESSED  = 2'b01;
    localparam [1:0] RELEASED = 2'b10;
    
    // Counter width
    localparam CNT_WIDTH = $clog2(DELAY_THRESHOLD + 1);
    
    reg [1:0] state, next_state;
    reg [CNT_WIDTH-1:0] counter;
    
    // State transition
    always @(posedge clk) begin
        state <= next_state;
    end
    
    // Counter logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                counter <= 0;
            end
            RELEASED: begin
                if (counter < DELAY_THRESHOLD)
                    counter <= counter + 1;
            end
            default: begin
                counter <= 0;
            end
        endcase
    end
    
    // Output and next state logic
    always @(*) begin
        // defaults
        next_state = state;
        debounced = 1'b0;
        
        case (state)
            IDLE: begin
                debounced = 1'b0;
                if (signal)
                    next_state = PRESSED;
                else
                    next_state = IDLE;
            end
            PRESSED: begin
                debounced = 1'b1;
                if (signal)
                    next_state = PRESSED;
                else
                    next_state = RELEASED;
            end
            RELEASED: begin
                debounced = 1'b0;
                if (counter >= DELAY_THRESHOLD)
                    next_state = IDLE;
                else
                    next_state = RELEASED;
            end
        endcase
    end
    
    // Initialize state (for simulation)
    initial begin
        state = IDLE;
        counter = 0;
    end
    
endmodule

module testbench;
    reg clk;
    reg signal;
    wire debounced;
    
    // Instantiate with small threshold for simulation
    ButtonDebouncer #(.DELAY_THRESHOLD(5)) dut (
        .clk(clk),
        .signal(signal),
        .debounced(debounced)
    );
    
    // Clock generation (10 ns period)
    always #5 clk = ~clk;
    
    // Stimulus
    initial begin
        clk = 0;
        signal = 0;
        
        // Wait a few cycles
        #100;
        
        // Press button (simple, without bounces)
        signal = 1;
        #100;
        signal = 0;
        
        #200;
        $finish;
    end
    
endmodule
