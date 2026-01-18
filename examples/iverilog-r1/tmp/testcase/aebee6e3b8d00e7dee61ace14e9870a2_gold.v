module CRA64 (X,Y,Z,S,ZR,C,P,O); //CarryRippleAdder
input[63:0] X,Y;
output[63:0] Z;
output S,C,ZR,P,O;
wire c[15:1];
assign S = Z[63];
assign ZR = ~|Z;
assign P = ~^Z;
assign O =(X[63]&Y[63]&~Z[63])|(~X[63]&~Y[63]&Z[63]);
adder_4 A0(Z[3:0],c[1],X[3:0],Y[3:0],1'b0);
adder_4 A1(Z[7:4],c[2],X[7:4],Y[7:4],c[1]);
adder_4 A2(Z[11:8],c[3],X[11:8],Y[11:8],c[2]);
adder_4 A3(Z[15:12],c[4],X[15:12],Y[15:12],c[3]);
adder_4 A4(Z[19:16],c[5],X[19:16],Y[19:16],c[4]);
adder_4 A5(Z[23:20],c[6],X[23:20],Y[23:20],c[5]);
adder_4 A6(Z[27:24],c[7],X[27:24],Y[27:24],c[6]);
adder_4 A7(Z[31:28],c[8],X[31:28],Y[31:28],c[7]);
adder_4 A8(Z[35:32],c[9],X[35:32],Y[35:32],c[8]);
adder_4 A9(Z[39:36],c[10],X[39:36],Y[39:36],c[9]);
adder_4 A10(Z[43:40],c[11],X[43:40],Y[43:40],c[10]);
adder_4 A11(Z[47:44],c[12],X[47:44],Y[47:44],c[11]);
adder_4 A12(Z[51:48],c[13],X[51:48],Y[51:48],c[12]);
adder_4 A13(Z[55:52],c[14],X[55:52],Y[55:52],c[13]);
adder_4 A14(Z[59:56],c[15],X[59:56],Y[59:56],c[14]);
adder_4 A15(Z[63:60],C,X[63:60],Y[63:60],c[15]);
endmodule
module adder_4 (S,cout,A,B,cin); //4-bit CarryRippleAdder
input[3:0] A,B;
input cin;
output cout;
output [3:0] S;
assign {cout,S} = A + B + cin;
endmodule