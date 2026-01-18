// Verilog code that resulted in empty output
// Saved at: 2026-01-15T08:24:51.230015
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

module vndecorrelator (
    input clk,
    input reset_n,
    input data_in,
    input syn_in,
    output reg data_out,
    output reg syn_out
);

    // States
    localparam [0:0] IDLE = 1'b0;
    localparam [0:0] CTRL_BITS = 1'b1;
    
    reg state;      // current state
    reg bit1_reg;   // latched first bit of pair
    
    // Next state logic (combinational)
    reg next_state;
    always @(*) begin
        next_state = state; // default stay in current state
        case (state)
            IDLE: begin
                if (syn_in)
                    next_state = CTRL_BITS;
            end
            CTRL_BITS: begin
                if (syn_in)
                    next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic (registers)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            bit1_reg <= 1'b0;
            data_out <= 1'b0;
            syn_out <= 1'b0;
        end else begin
            state <= next_state;
            
            // Latch first bit when moving to CTRL_BITS
            if (state == IDLE && syn_in) begin
                bit1_reg <= data_in;
            end
            
            // Output logic
            if (state == CTRL_BITS && syn_in && (bit1_reg != data_in)) begin
                data_out <= bit1_reg;
                syn_out <= 1'b1;
            end else begin
                syn_out <= 1'b0;
            end
        end
    end
    
endmodule

module testbench;
    reg clk;
    reg reset_n;
    reg data_in;
    reg syn_in;
    wire data_out;
    wire syn_out;
    
    vndecorrelator dut (.*);
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        reset_n = 0;
        data_in = 0;
        syn_in = 0;
        #20;
        reset_n = 1;
        #20;
        $finish;
    end
endmodule
