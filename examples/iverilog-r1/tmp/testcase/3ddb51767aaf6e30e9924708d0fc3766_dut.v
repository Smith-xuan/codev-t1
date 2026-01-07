module rs_latch(
    input s,
    input r,
    output q,
    output qn
);
    // Gate-level RS latch using NAND gates
    assign q = ~(s & qn);
    assign qn = ~(r & q);
endmodule