/**
 * Alarm System Module
 *
 * Controls LED and buzzer based on alarm signal with clock division.
 *
 * Interface:
 *   clk      - Main clock input
 *   alarm    - Alarm signal (1=active, 0=inactive)
 *   led      - LED output (blinks at divided clock rate when alarm active, off otherwise)
 *   buzzer   - Buzzer output (toggles at divided clock rate when alarm active, on otherwise)
 *
 * When alarm=1:
 *   - LED blinks at divided clock rate (toggles on each tick)
 *   - Buzzer toggles at divided clock rate
 *
 * When alarm=0:
 *   - LED is off (0)
 *   - Buzzer is on (1)
 *
 * Implementation uses a clock divider counter that generates a tick every
 * DIVIDER clock cycles. Both LED and buzzer outputs toggle on each tick
 * when alarm is active.
 */
module Alarm #(
    parameter DIVIDER = 50_000_000  // Default: 1 Hz at 100 MHz clock
) (
    input wire clk,
    input wire alarm,
    output reg led,
    output reg buzzer
);

    // Clock divider counter and toggle registers
    // Counter counts from 0 to DIVIDER-1 (wraps at DIVIDER-1)
    // Toggle registers flip on each tick when counter reaches DIVIDER-1
    reg [DIVIDER-1:0] counter = 0;
    reg led_toggle = 0;
    reg buzzer_toggle = 0;

    // Tick generation: indicates when counter reaches maximum
    wire tick;

    // Sequential logic for counter and toggle registers
    always @(posedge clk) begin
        if (counter == DIVIDER - 1) begin
            // End of count period - reset counter and toggle outputs
            counter <= 0;
            led_toggle <= ~led_toggle;
            buzzer_toggle <= ~buzzer_toggle;
        end else begin
            // Increment counter
            counter <= counter + 1;
        end
    end

    // Tick signal generated combinationally for immediate toggle detection
    assign tick = (counter == DIVIDER - 1);

    // Combinational output logic
    always @(*) begin
        if (alarm) begin
            // Alarm active: outputs follow toggle registers
            led = led_toggle;
            buzzer = buzzer_toggle;
        end else begin
            // Alarm inactive: LED off, buzzer on
            led = 1'b0;
            buzzer = 1'b1;
        end
    end

endmodule