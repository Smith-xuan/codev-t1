// Verilog code that resulted in empty output
// Saved at: 2026-01-07T03:57:14.181657
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

module uart_rx #(
    parameter OVERSAMPLE = 16
) (
    input wire clk,
    input wire rst,
    input wire rx,
    output reg [7:0] data,
    output reg done
);

    localparam [1:0] IDLE  = 2'b00;
    localparam [1:0] START = 2'b01;
    localparam [1:0] DATA  = 2'b10;
    localparam [1:0] STOP  = 2'b11;

    reg [1:0] state, next_state;
    reg [3:0] clk_div;      // oversample counter (0 to OVERSAMPLE-1)
    reg [2:0] bit_index;    // index of data bit (0 to 7)
    reg [7:0] shift_reg;    // shift register for receiving data
    reg stop_bit_valid;     // flag indicating stop bit was valid

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        stop_bit_valid = 1'b0; // default
        case (state)
            IDLE: begin
                if (rx == 1'b0) begin
                    next_state = START;
                end
            end
            START: begin
                // Wait for middle of start bit (clk_div == OVERSAMPLE/2 - 1)
                if (clk_div == (OVERSAMPLE/2 - 1)) begin
                    if (rx == 1'b0) begin
                        next_state = DATA;
                    end else begin
                        next_state = IDLE; // false start
                    end
                end
            end
            DATA: begin
                // After sampling 8 data bits, go to STOP
                if (bit_index == 3'd7 && clk_div == (OVERSAMPLE/2 - 1)) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                // Sample stop bit at middle, then go to IDLE after full bit period
                if (clk_div == (OVERSAMPLE/2 - 1) && rx == 1'b1) begin
                    stop_bit_valid = 1'b1;
                end
                if (clk_div == (OVERSAMPLE-1)) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            clk_div <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            data <= 0;
            done <= 0;
            stop_bit_valid <= 0;
        end else begin
            state <= next_state;
            stop_bit_valid <= 0; // clear unless set combinational

            // Increment oversample counter
            if (clk_div == (OVERSAMPLE-1)) begin
                clk_div <= 0;
            end else begin
                clk_div <= clk_div + 1;
            end

            // Control logic based on state
            case (state)
                IDLE: begin
                    clk_div <= 0;
                    bit_index <= 0;
                end
                START: begin
                    // Wait for middle of start bit
                    if (clk_div == (OVERSAMPLE/2 - 1)) begin
                        // Sample start bit
                        if (rx == 1'b0) begin
                            // Valid start, stay in START for one cycle?
                            // Actually we need to reset clk_div for next phase
                            clk_div <= 0;
                        end else begin
                            // false start, will transition to IDLE
                        end
                    end
                end
                DATA: begin
                    // Sample data at middle of bit
                    if (clk_div == (OVERSAMPLE/2 - 1)) begin
                        // Shift in LSB first
                        shift_reg <= {rx, shift_reg[7:1]};
                        bit_index <= bit_index + 1;
                    end
                    // Reset clk_div at end of bit period
                    if (clk_div == (OVERSAMPLE-1)) begin
                        clk_div <= 0;
                    end
                end
                STOP: begin
                    // Sample stop bit at middle (already checked combinational)
                    if (clk_div == (OVERSAMPLE/2 - 1)) begin
                        // Check stop bit (should be 1)
                        // No action needed
                    end
                    // At end of stop bit period, assert done if stop bit valid
                    if (clk_div == (OVERSAMPLE-1)) begin
                        if (stop_bit_valid) begin
                            data <= shift_reg;
                            done <= 1'b1;
                        end else begin
                            done <= 1'b0;
                        end
                    end
                end
                default: ;
            endcase
        end
    end

endmodule

module testbench;
    reg clk;
    reg rst;
    reg rx;
    wire [7:0] data;
    wire done;

    uart_rx #(.OVERSAMPLE(16)) dut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data(data),
        .done(done)
    );

    // Clock generation (100 MHz => 10 ns period)
    always #5 clk = ~clk;

    // Simulate UART transmission of byte 0x55 (01010101 LSB first)
    // Start bit (0), then bits: 1,0,1,0,1,0,1,0, stop bit (1)
    // Bit period = 16 clock cycles = 160 ns

    initial begin
        clk = 0;
        rst = 1;
        rx = 1; // idle high

        // Apply reset
        #100;
        rst = 0;
        #10;

        // Start bit
        rx = 0; // start bit
        #160; // one bit period

        // Data bits LSB first
        // Bit 0: 1
        rx = 1;
        #160;
        // Bit 1: 0
        rx = 0;
        #160;
        // Bit 2: 1
        rx = 1;
        #160;
        // Bit 3: 0
        rx = 0;
        #160;
        // Bit 4: 1
        rx = 1;
        #160;
        // Bit 5: 0
        rx = 0;
        #160;
        // Bit 6: 1
        rx = 1;
        #160;
        // Bit 7: 0
        rx = 0;
        #160;

        // Stop bit
        rx = 1;
        #160;

        // Wait for receiver to process
        #200;

        // Send another byte 0xAA (10101010 LSB first)
        rx = 0; // start
        #160;
        // Bit 0: 0
        rx = 0;
        #160;
        // Bit 1: 1
        rx = 1;
        #160;
        // Bit 2: 0
        rx = 0;
        #160;
        // Bit 3: 1
        rx = 1;
        #160;
        // Bit 4: 0
        rx = 0;
        #160;
        // Bit 5: 1
        rx = 1;
        #160;
        // Bit 6: 0
        rx = 0;
        #160;
        // Bit 7: 1
        rx = 1;
        #160;
        // Stop bit
        rx = 1;
        #160;

        #500;
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (done) begin
            $display("Time %t: Received data: 0x%h", $time, data);
        end
    end

endmodule
