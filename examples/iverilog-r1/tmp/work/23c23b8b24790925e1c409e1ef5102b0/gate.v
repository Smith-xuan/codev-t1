module clocked_Sr_latch_gate(enable, set, reset, q_out, q_bar);
  input enable, set, reset;
  output q_out, q_bar;
  wire set_n, reset_n;
  assign set_n = ~(set & enable);
  assign reset_n = ~(reset & enable);
  assign q_out = ~(set_n & q_bar);
  assign q_bar = ~(reset_n & q_out);
endmodule