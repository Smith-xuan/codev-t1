// Full Adder module - basic building block
module FA(input a, b, cin, output sum, cout);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

// 4-bit carry ripple adder module
module CRA4(input [3:0] A, B, input cin, output [3:0] S, output Cout);
    wire c0, c1, c2;
    FA fa0(A[0], B[0], cin, S[0], c0);
    FA fa1(A[1], B[1], c0, S[1], c1);
    FA fa2(A[2], B[2], c1, S[2], c2);
    FA fa3(A[3], B[3], c2, S[3], Cout);
endmodule

// 64-bit carry ripple adder with hierarchical 4-bit segments
module CRA64(
    input [63:0] X,
    input [63:0] Y,
    output [63:0] Z,
    output S,
    output C,
    output ZR,
    output P,
    output O
);
    // Internal carry wires between segments
    wire [16:0] carry; // carry[0] = cin to segment 0 (0), carry[i] is cout from segment i-1
    assign carry[0] = 1'b0;

    // Generate 16 instances of 4-bit carry ripple adders
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : seg
            CRA4 cra4 (
                .A(X[i*4 +: 4]),
                .B(Y[i*4 +: 4]),
                .cin(carry[i]),
                .S(Z[i*4 +: 4]),
                .Cout(carry[i+1])
            );
        end
    endgenerate

    // Carry out flag (overall carry from addition)
    assign C = carry[16]; // carry[16] is the final carry after segment 15

    // Zero flag: high if Z is zero
    assign ZR = (Z == 64'b0);

    // Sign flag: most significant bit of Z
    assign S = Z[63];

    // Parity flag: high if number of '1's in Z is even
    // Reduction XOR gives 1 if odd number of 1s, so parity even => invert
    assign P = ~^Z;

    // Overflow flag: detect signed overflow using standard definition
    // Overflow occurs when:
    // 1. Adding two positive numbers (sign bits of X and Y both 0) yields negative (Z sign bit 1)
    // 2. Adding two negative numbers (sign bits of X and Y both 1) yields positive (Z sign bit 0)
    assign O = (X[63]==1'b0 && Y[63]==1'b0 && Z[63]==1'b1) ||
               (X[63]==1'b1 && Y[63]==1'b1 && Z[63]==1'b0);

endmodule