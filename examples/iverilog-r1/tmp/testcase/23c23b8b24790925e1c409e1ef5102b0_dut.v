module clocked_Sr_latch(enable, set, reset, q_out, q_bar);
  input enable, set, reset;
  output q_out, q_bar;

  // Internal signals: gates 1 and 2 generate gated active-low signals
  wire set_n, reset_n;

  // Gate 1: set_n = NAND(set, enable)  // level-sensitive gating
  assign set_n = ~(set & enable);

  // Gate 2: reset_n = NAND(reset, enable)
  assign reset_n = ~(reset & enable);

  // Gate 3: q_out = NAND(set_n, q_bar)  // cross-coupled latch
  assign q_out = ~(set_n & q_bar);

  // Gate 4: q_bar = NAND(reset_n, q_out)
  assign q_bar = ~(reset_n & q_out);

endmodule