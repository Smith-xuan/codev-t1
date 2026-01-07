`timescale 1ns/1ns

module Bin2BCD_2 (
    input  [7:0] binary,
    output [3:0] tens,
    output [3:0] ones
);

    reg [3:0] tens_reg, ones_reg;
    integer i;

    always @(*) begin
        tens_reg = 4'b0;
        ones_reg = 4'b0;
        for (i = 7; i >= 0; i = i - 1) begin
            // Add 3 if digit >= 5
            if (tens_reg >= 5) tens_reg = tens_reg + 3;
            if (ones_reg >= 5) ones_reg = ones_reg + 3;
            // Shift left the combined digits and insert binary bit
            tens_reg = (tens_reg << 1) | (ones_reg >> 3);
            ones_reg = (ones_reg << 1) | (binary >> i & 1);
        end
    end

    assign tens = tens_reg;
    assign ones = ones_reg;

endmodule