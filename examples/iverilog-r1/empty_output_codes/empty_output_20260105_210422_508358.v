// Verilog code that resulted in empty output
// Saved at: 2026-01-05T21:04:22.508389
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

module bluetooth #(
    parameter CLK_FREQ = 50_000_000, // System clock frequency in Hz
    parameter BAUD = 9600,           // Baud rate
    parameter OVERSAMPLE = 16        // Oversampling factor (16x)
) (
    input wire clk,
    input wire rst,
    input wire get,
    output reg [7:0] out
);

    // Calculate oversampling frequency
    localparam OVERSAMPLE_FREQ = OVERSAMPLE * BAUD;
    // Calculate divider integer: number of clock cycles per oversample tick
    localparam [31:0] OVERSAMPLE_DIV = (CLK_FREQ + (OVERSAMPLE_FREQ / 2)) / OVERSAMPLE_FREQ;
    
    // Oversample tick generation
    reg [31:0] prescaler;
    wire sample_tick = (prescaler == OVERSAMPLE_DIV - 1);
    always @(posedge clk) begin
        if (rst) begin
            prescaler <= 0;
        end else begin
            if (sample_tick) begin
                prescaler <= 0;
            end else begin
                prescaler <= prescaler + 1;
            end
        end
    end
    
    // Debouncing and start detection
    reg [3:0] shift_reg; // Shift register for debouncing
    reg start_detected;
    reg start_bit_status; // 0 = high, 1 = low (stable low)
    
    always @(posedge clk) begin
        if (rst) begin
            shift_reg <= 4'b1111; // Assume idle state is high
            start_detected <= 1'b0;
            start_bit_status <= 1'b0;
        end else if (sample_tick) begin
            // Shift in current get value (inverted if we want active-low start bit)
            shift_reg <= {shift_reg[2:0], get};
            
            // Detect falling edge: previous 4 samples high, current low
            // Actually we want stable low after falling edge.
            // We'll just set start_bit_status when we detect a low after being high.
            // For simplicity, we'll set start_bit_status high when shift_reg[3:1]==3'b111 and get==0.
            if (shift_reg[3:1] == 3'b111 && get == 0) begin
                start_bit_status <= 1'b1;
            end else if (shift_reg[2:0] == 3'b111 && get == 1) begin
                // If we saw a low but then high again, maybe false start.
                // We'll set start_bit_status low.
                start_bit_status <= 1'b0;
            end
        end else begin
            // Keep start_bit_status unchanged unless we are in start detection state
            // (handled below)
        end
    end
    
    // FSM states
    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;
    
    reg [1:0] state, next_state;
    reg [3:0] sample_cnt; // Counts 0-15 for oversampling within bit period
    reg [7:0] shift_reg_data; // Shift register to collect data bits
    reg [2:0] bit_cnt; // Counts 0-7 for data bits
    
    // Oversample counter increments on sample_tick
    always @(posedge clk) begin
        if (rst) begin
            sample_cnt <= 0;
        end else if (sample_tick) begin
            if (state == IDLE) begin
                sample_cnt <= 0;
            end else begin
                sample_cnt <= sample_cnt + 1;
                if (sample_cnt == 4'd15) begin
                    sample_cnt <= 0;
                end
            end
        end
    end
    
    // Bit period counter (could be derived from sample_cnt, but we need bit_cnt)
    // We'll use sample_cnt to know when to sample: at 8 (midpoint)
    
    // Data shift register for collecting bits
    always @(posedge clk) begin
        if (rst) begin
            shift_reg_data <= 8'b0;
            bit_cnt <= 3'b0;
        end else begin
            case (state)
                DATA: begin
                    if (sample_tick && sample_cnt == 4'd8) begin
                        // Sample the data bit at midpoint
                        shift_reg_data <= {shift_reg_data[6:0], get}; // LSB first
                    end
                    if (sample_tick && sample_cnt == 4'd15) begin
                        // Increment bit counter after completing a bit period
                        bit_cnt <= bit_cnt + 1;
                    end
                    if (sample_tick && sample_cnt == 4'd15 && bit_cnt == 3'd7) begin
                        // All bits received
                        bit_cnt <= 3'd0;
                    end
                end
                default: begin
                    bit_cnt <= 3'b0;
                end
            endcase
        end
    end
    
    // State machine
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_bit_status) begin
                    next_state = START;
                end
            end
            START: begin
                if (sample_tick && sample_cnt == 4'd7) begin
                    // Wait half bit period (8 oversample ticks) and sample start bit at midpoint
                    // If get is still low, proceed to DATA, else go back to IDLE
                    if (get == 0) begin
                        next_state = DATA;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            DATA: begin
                if (sample_tick && sample_cnt == 4'd15 && bit_cnt == 3'd7) begin
                    // Received all 8 data bits
                    next_state = STOP;
                end
            end
            STOP: begin
                if (sample_tick && sample_cnt == 4'd8) begin
                    // Sample stop bit at midpoint
                    if (get == 1) begin
                        // Valid stop bit
                        out <= shift_reg_data;
                    end
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end
    
endmodule

// Testbench
module testbench;
    reg clk;
    reg rst;
    reg get;
    wire [7:0] out;
    
    // Instantiate DUT with smaller clock frequency for faster simulation
    bluetooth #(
        .CLK_FREQ(1000000), // 1 MHz for faster simulation
        .BAUD(9600)
    ) dut (
        .clk(clk),
        .rst(rst),
        .get(get),
        .out(out)
    );
    
    // Clock generation: 10 ns period (100 MHz) but we changed CLK_FREQ to 1 MHz?
    // Actually CLK_FREQ parameter is for divider calculation; the clock frequency in testbench
    // is separate. We'll keep clock at 100 MHz, but the divider will be based on 1 MHz parameter.
    // That's okay; the design uses CLK_FREQ parameter for divider, not the actual clock frequency.
    // However, the actual clock frequency is 100 MHz in simulation, but divider is computed as 1 MHz.
    // That mismatch will cause wrong timing. Let's adjust: we need to ensure simulation matches.
    // Better to set CLK_FREQ to actual clock frequency used in testbench.
    // Let's set clock to 1 MHz for simplicity.
    // But then simulation will be slow. Let's set clock to 10 MHz.
    // Actually, we can set CLK_FREQ to 10_000_000 (10 MHz) and clock to 10 MHz period 100 ns.
    // Let's do that.
    
    // Let's re-define with correct parameters.
    // We'll create a separate module with parameters.
    
    // Let's start over with proper testbench.
endmodule
