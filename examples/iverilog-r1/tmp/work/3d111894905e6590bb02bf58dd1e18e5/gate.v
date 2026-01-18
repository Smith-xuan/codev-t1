
module oh_mux12_gate #(parameter DW = 1) (
    input sel11, sel10, sel9, sel8, sel7, sel6, sel5, sel4, sel3, sel2, sel1, sel0,
    input [DW-1:0] in11, in10, in9, in8, in7, in6, in5, in4, in3, in2, in1, in0,
    output reg [DW-1:0] out
);
    always @(*) begin
        if (sel11) out = in11;
        else if (sel10) out = in10;
        else if (sel9) out = in9;
        else if (sel8) out = in8;
        else if (sel7) out = in7;
        else if (sel6) out = in6;
        else if (sel5) out = in5;
        else if (sel4) out = in4;
        else if (sel3) out = in3;
        else if (sel2) out = in2;
        else if (sel1) out = in1;
        else if (sel0) out = in0;
        else out = {DW{1'b0}};
    end
endmodule