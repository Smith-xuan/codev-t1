
module altera_up_avalon_video_lt24_write_sequencer_gate (
    input  wire        clk,
    input  wire        reset,
    input  wire        wait_sig,
    output wire        wrx
);
    localparam [1:0] WAIT = 2'b00,
                     SETUP = 2'b01,
                     LATCH = 2'b10;
    reg [1:0] state, next_state;
    always @(posedge clk) begin
        if (reset) begin
            state <= WAIT;
        end else begin
            state <= next_state;
        end
    end
    always @(*) begin
        case (state)
            WAIT: begin
                if (!wait_sig) begin
                    next_state = SETUP;
                end else begin
                    next_state = WAIT;
                end
            end
            SETUP: begin
                next_state = LATCH;
            end
            LATCH: begin
                if (wait_sig) begin
                    next_state = WAIT;
                end else begin
                    next_state = SETUP;
                end
            end
            default: begin
                next_state = WAIT;
            end
        endcase
    end
    assign wrx = (state == WAIT || state == LATCH) ? 1'b1 : 1'b0;
endmodule