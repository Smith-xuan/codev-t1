
module Alarm_gate #(
    parameter DIVIDER = 50_000_000
) (
    input wire clk,
    input wire alarm,
    output reg led,
    output reg buzzer
);
    reg [DIVIDER-1:0] counter = 0;
    reg led_toggle = 0;
    reg buzzer_toggle = 0;
    wire tick;
    always @(posedge clk) begin
        if (counter == DIVIDER - 1) begin
            counter <= 0;
            led_toggle <= ~led_toggle;
            buzzer_toggle <= ~buzzer_toggle;
        end else begin
            counter <= counter + 1;
        end
    end
    assign tick = (counter == DIVIDER - 1);
    always @(*) begin
        if (alarm) begin
            led = led_toggle;
            buzzer = buzzer_toggle;
        end else begin
            led = 1'b0;
            buzzer = 1'b1;
        end
    end
endmodule