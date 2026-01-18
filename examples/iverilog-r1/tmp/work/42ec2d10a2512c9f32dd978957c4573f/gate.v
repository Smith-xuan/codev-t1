
module nand2_gate (input a, b, output y);
  assign y = ~(a & b);
endmodule
module jkstruct_gate (input j, k, clk, output q, qbar);
  wire w, x, y, z;
  nand2_gate g1 (.a(j), .b(clk), .y(w));
  nand2_gate g2 (.a(k), .b(clk), .y(x));
  nand2_gate g3 (.a(w), .b(qbar), .y(y));
  nand2_gate g4 (.a(x), .b(q), .y(z));
  nand2_gate g5 (.a(y), .b(z), .y(qbar));
  wire q_internal;
  nand2_gate g3a (.a(w), .b(qbar), .y(q_internal));
  nand2_gate g4a (.a(x), .b(q_internal), .y(qbar));
  wire q_latch, qbar_latch;
  nand2_gate latch1 (.a(w), .b(qbar), .y(q_latch));
  nand2_gate latch2 (.a(x), .b(q_latch), .y(qbar_latch));
  assign q = q_latch;
  assign qbar = qbar_latch;
endmodule