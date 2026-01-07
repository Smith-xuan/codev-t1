/*
 * Video display interface write sequencer (ALTERA style)
 *
 * Three-state machine: WAIT, SETUP, LATCH.
 *
 * Transitions:
 *   WAIT -> (wait_sig == 0) SETUP
 *   SETUP -> LATCH always
 *   LATCH -> (wait_sig == 1) WAIT else SETUP
 *
 * Outputs:
 *   wrx = 0 during SETUP state, 1 in all other states.
 *
 * Reset: active-high, forces state to WAIT.
 *
 * All transitions and outputs are edge-triggered on rising clock edge.
 */
module altera_up_avalon_video_lt24_write_sequencer (
    input  wire        clk,   // Clock
    input  wire        reset, // Active-high reset
    input  wire        wait_sig,  // Wait signal (0 = proceed)
    output wire        wrx   // Write enable control
);

    // State encoding (2 bits, values: 00 = WAIT, 01 = SETUP, 10 = LATCH)
    localparam [1:0] WAIT = 2'b00,
                     SETUP = 2'b01,
                     LATCH = 2'b10;

    // Internal state registers
    reg [1:0] state, next_state;

    // Sequential state register (synchronous to rising clock)
    always @(posedge clk) begin
        if (reset) begin
            state <= WAIT;
        end else begin
            state <= next_state;
        end
    end

    // Combinational next-state logic
    always @(*) begin
        case (state)
            WAIT: begin
                // Wait until wait_sig goes low
                if (!wait_sig) begin
                    next_state = SETUP;
                end else begin
                    next_state = WAIT;
                end
            end

            SETUP: begin
                // Always go to LATCH from SETUP
                next_state = LATCH;
            end

            LATCH: begin
                // Return to WAIT if wait_sig is high, otherwise to SETUP
                if (wait_sig) begin
                    next_state = WAIT;
                end else begin
                    next_state = SETUP;
                end
            end

            default: begin
                // Safety: return to WAIT if any unexpected state
                next_state = WAIT;
            end
        endcase
    end

    // Output logic: wrx is 1 in WAIT and LATCH states, 0 in SETUP
    assign wrx = (state == WAIT || state == LATCH) ? 1'b1 : 1'b0;

endmodule