module Bin2BCD_8bits (
    input [7:0] Bin,
    output reg [3:0] Least,
    output reg [3:0] Most
);

    // Double Dabble algorithm for 8-bit binary to 2-digit BCD
    integer i;
    reg [15:0] bcd; // 16 bits: bits [15:8] BCD digits, bits [7:0] binary
    always @(*) begin
        // Initialize: two BCD digits (4 bits each) zero, binary in lower 8 bits
        bcd = {4'b0, 4'b0, Bin};

        // Process each bit (8 bits)
        for (i = 7; i >= 0; i = i - 1) begin
            // Check most significant BCD digit (bits [15:12])
            if (bcd[15:12] >= 5)
                bcd[15:12] = bcd[15:12] + 3;
            // Check least significant BCD digit (bits [11:8])
            if (bcd[11:8] >= 5)
                bcd[11:8] = bcd[11:8] + 3;
            // Shift left by 1
            bcd = bcd << 1;
        end

        // After 8 shifts, the BCD digits are in bits [15:8]
        Most = bcd[15:12];
        Least = bcd[11:8];
    end

endmodule