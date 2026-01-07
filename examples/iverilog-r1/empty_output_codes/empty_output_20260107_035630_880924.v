// Verilog code that resulted in empty output
// Saved at: 2026-01-07T03:56:30.881015
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
    reg [3:0] bit_timer;    // counts oversample cycles within a bit
    reg [2:0] bit_index;    // index of data bit (0 to 7)
    reg [7:0] shift_reg;    // shift register for receiving data

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (rx == 1'b0) begin
                    next_state = START;
                end
            end
            START: begin
                if (clk_div == (OVERSAMPLE/2 - 1)) begin // wait for half bit period
                    if (rx == 1'b0) begin
                        next_state = DATA;
                    end else begin
                        next_state = IDLE; // false start
                    end
                end
            end
            DATA: begin
                if (bit_timer == (OVERSAMPLE-1)) begin // completed 8 data bits?
                    // We need to check if bit_index == 7 after sampling 8th bit
                    if (bit_index == 3'd7) begin
                        next_state = STOP;
                    end
                end
            end
            STOP: begin
                if (bit_timer == (OVERSAMPLE-1)) begin // wait for bit period
                    // sample stop bit at middle, then after full bit period we can go to IDLE
                    // Actually we need to sample stop bit at middle, then after half bit period check?
                    // We'll stay in STOP for full bit period, then go to IDLE if stop bit valid.
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
            bit_timer <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            data <= 0;
            done <= 0;
        end else begin
            state <= next_state;

            // Oversample counter
            if (clk_div == (OVERSAMPLE-1)) begin
                clk_div <= 0;
            end else begin
                clk_div <= clk_div + 1;
            end

            // Bit timer and control
            case (state)
                IDLE: begin
                    clk_div <= 0;
                    bit_timer <= 0;
                    bit_index <= 0;
                end
                START: begin
                    if (clk_div == (OVERSAMPLE/2 - 1)) begin
                        // At this point, we have waited half a bit period.
                        // If still low, we are aligned.
                        // Reset clk_div for next state.
                        clk_div <= 0;
                    end
                end
                DATA: begin
                    if (clk_div == (OVERSAMPLE-1)) begin
                        clk_div <= 0;
                        bit_timer <= bit_timer + 1;
                    end
                    // Sample data at the middle of the bit (oversample count == OVERSAMPLE/2)
                    if (clk_div == (OVERSAMPLE/2 - 1)) begin
                        shift_reg <= {rx, shift_reg[7:1]}; // LSB first
                        bit_index <= bit_index + 1;
                    end
                end
                STOP: begin
                    if (clk_div == (OVERSAMPLE-1)) begin
                        clk_div <= 0;
                        bit_timer <= bit_timer + 1;
                    end
                    // Sample stop bit at middle
                    if (clk_div == (OVERSAMPLE/2 - 1)) begin
                        // Check stop bit (should be 1) maybe set a flag
                    end
                    // After full bit period, move to IDLE if stop bit valid
                    if (bit_timer == (OVERSAMPLE-1)) begin
                        // Check stop bit: we need to ensure rx is 1 at the middle.
                        // We'll have a registered flag.
                        // For now, go to IDLE if rx is 1 (maybe).
                        if (rx == 1'b1) begin
                            data <= shift_reg;
                            done <= 1'b1;
                        end else begin
                            done <= 1'b0;
                        end
                        // State transition handled by combinational logic
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

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        rx = 1; // idle high

        // Reset
        #20;
        rst = 0;
        #10;

        // Send start bit (0)
        rx = 0;
        #160; // wait for 10 bit periods? Actually oversample factor 16, we need to simulate correct timing.
        // We'll just wait for a while and then send data bits.
        // Let's simulate a byte 0x55 (01010101 binary, LSB first)
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
        // Stop bit: 1
        rx = 1;
        #160;
        // Wait a bit more
        #200;
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (done) begin
            $display("Received data: 0x%h", data);
        end
    end

endmodule
