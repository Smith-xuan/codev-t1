module pg2_gate (
    input       cin,
    input  [1:0] p,
    input  [1:0] g,
    output [1:0] c
);
    assign c[0] = g[0] | (p[0] & cin);
    assign c[1] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
endmodule