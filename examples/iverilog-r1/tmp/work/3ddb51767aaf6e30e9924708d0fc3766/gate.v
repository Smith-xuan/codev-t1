module rs_latch_gate(
    input s,
    input r,
    output q,
    output qn
);
    assign q = ~(s & qn);
    assign qn = ~(r & q);
endmodule