module Bin2BCD_8bits (
    input [7:0] Bin,
    output [3:0] Least,
    output [3:0] Most
);

// Double Dabble algorithm for 8-bit to two BCD digits
reg [15:0] shift;
always @(*) begin
    // Initialize shift register with bin in upper bits (bits 15:8) and zeros in lower bits
    shift = {Bin, 8'b0};

    // Perform 16 iterations (bits 0 to 15)
    for (integer i = 0; i < 16; i = i + 1) begin
        if (shift[0] == 1'b1) begin
            // When LSB is 1, shift left and set bits 9-12 to 1 (add 4 to those positions)
            shift = {shift[15:0], 4'b1111, 1'b0};
        end else begin
            // Shift left normally
            shift = {shift[15:0], 1'b0};
        end
    end
end

// Extract BCD digits
assign Least = shift[3:0];                     // Lower nibble of final result (LSB of BCD digits)
assign Most = shift[7:4];                      // Upper nibble of final result (MSB of BCD digits)

endmodule

// Reference model for comparison
module BCD_ref (
    input [7:0] bin,
    output [3:0] tens,
    output [3:0] ones
);
reg [15:0] ref_shift;
integer i;
always @(*) begin
    ref_shift = {bin, 8'b0};
    for (i = 0; i < 16; i = i + 1) begin
        if (ref_shift[0] == 1'b1) begin
            ref_shift = {ref_shift[15:0], 4'b1111, 1'b0};
        end else begin
            ref_shift = {ref_shift[15:0], 1'b0};
        end
    end
end
assign tens = ref_shift[7:4];
assign ones = ref_shift[3:0];
endmodule