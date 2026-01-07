module Bin2BCD_8bits_gate (
    input [7:0] Bin,
    output reg [3:0] Least,
    output reg [3:0] Most
);
    integer i;
    reg [15:0] bcd;
    always @(*) begin
        bcd = {4'b0, 4'b0, Bin};
        for (i = 7; i >= 0; i = i - 1) begin
            if (bcd[15:12] >= 5)
                bcd[15:12] = bcd[15:12] + 3;
            if (bcd[11:8] >= 5)
                bcd[11:8] = bcd[11:8] + 3;
            bcd = bcd << 1;
        end
        Most = bcd[15:12];
        Least = bcd[11:8];
    end
endmodule