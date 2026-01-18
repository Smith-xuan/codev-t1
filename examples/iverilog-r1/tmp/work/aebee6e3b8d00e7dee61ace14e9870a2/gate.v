
module FA_gate(input a, b, cin, output sum, cout);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule
module CRA4_gate(input [3:0] A, B, input cin, output [3:0] S, output Cout);
    wire c0, c1, c2;
    FA_gate fa0(A[0], B[0], cin, S[0], c0);
    FA_gate fa1(A[1], B[1], c0, S[1], c1);
    FA_gate fa2(A[2], B[2], c1, S[2], c2);
    FA_gate fa3(A[3], B[3], c2, S[3], Cout);
endmodule
module CRA64_gate(
    input [63:0] X,
    input [63:0] Y,
    output [63:0] Z,
    output S,
    output C,
    output ZR,
    output P,
    output O
);
    wire [16:0] carry;
    assign carry[0] = 1'b0;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : seg
            CRA4_gate cra4 (
                .A(X[i*4 +: 4]),
                .B(Y[i*4 +: 4]),
                .cin(carry[i]),
                .S(Z[i*4 +: 4]),
                .Cout(carry[i+1])
            );
        end
    endgenerate
    assign C = carry[16];
    assign ZR = (Z == 64'b0);
    assign S = Z[63];
    assign P = ~^Z;
    assign O = (X[63]==1'b0 && Y[63]==1'b0 && Z[63]==1'b1) ||
               (X[63]==1'b1 && Y[63]==1'b1 && Z[63]==1'b0);
endmodule