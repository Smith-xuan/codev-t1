module pg2 (
    input       cin,
    input  [1:0] p,
    input  [1:0] g,
    output [1:0] c
);
    // Carry-lookahead generator for a 2-bit adder.
    // Inputs:
    //   cin - carry-in signal
    //   p   - 2-bit propagate vector (p[0], p[1])
    //   g   - 2-bit generate vector (g[0], g[1])
    // Outputs:
    //   c   - 2-bit carry signal vector:
    //         c[0] = c[1] (carry into bit 1 / carry out of bit 0)
    //         c[1] = c[2] (carry into bit 2 / carry out of bit 1)
    // Logic equations:
    //   c[1] = g[0] | (p[0] & cin)
    //   c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin)
    assign c[0] = g[0] | (p[0] & cin);
    assign c[1] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
endmodule