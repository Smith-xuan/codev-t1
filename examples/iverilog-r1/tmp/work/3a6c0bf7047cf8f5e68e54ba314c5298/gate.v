module Bin2BCD_8bits_gate (
    input [7:0] Bin,
    output [3:0] Least,
    output [3:0] Most
);
reg [15:0] shift;
always @(*) begin
    shift = {Bin, 8'b0};
    for (integer i = 0; i < 16; i = i + 1) begin
        if (shift[0] == 1'b1) begin
            shift = {shift[15:0], 4'b1111, 1'b0};
        end else begin
            shift = {shift[15:0], 1'b0};
        end
    end
end
assign Least = shift[3:0];
assign Most = shift[7:4];
endmodule
module BCD_ref_gate (
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