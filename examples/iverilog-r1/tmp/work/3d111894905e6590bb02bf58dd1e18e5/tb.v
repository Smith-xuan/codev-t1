
module oh_mux12_gold #(parameter DW = 1 )
   (
     input 	     sel11,
     input 	     sel10,
     input 	     sel9,
     input 	     sel8,
     input 	     sel7,
     input 	     sel6,
     input 	     sel5,
     input 	     sel4,
     input 	     sel3,
     input 	     sel2,
     input 	     sel1,
     input 	     sel0,
     input [DW-1:0]  in11,
     input [DW-1:0]  in10,
     input [DW-1:0]  in9,
     input [DW-1:0]  in8,
     input [DW-1:0]  in7,
     input [DW-1:0]  in6,
     input [DW-1:0]  in5,
     input [DW-1:0]  in4,
     input [DW-1:0]  in3,
     input [DW-1:0]  in2,
     input [DW-1:0]  in1,
     input [DW-1:0]  in0,
     output [DW-1:0] out
    );
   assign out[DW-1:0] = ({(DW){sel0}}  & in0[DW-1:0] |
			 {(DW){sel1}}  & in1[DW-1:0] |
			 {(DW){sel2}}  & in2[DW-1:0] |
			 {(DW){sel3}}  & in3[DW-1:0] |
			 {(DW){sel4}}  & in4[DW-1:0] |
			 {(DW){sel5}}  & in5[DW-1:0] |
			 {(DW){sel6}}  & in6[DW-1:0] |
			 {(DW){sel7}}  & in7[DW-1:0] |
			 {(DW){sel8}}  & in8[DW-1:0] |
			 {(DW){sel9}}  & in9[DW-1:0] |
			 {(DW){sel10}} & in10[DW-1:0] |
			 {(DW){sel11}} & in11[DW-1:0]);
endmodule 


module testbench;
    reg [0:0] in5_in ;
    reg [0:0] in8_in ;
    reg [0:0] in9_in ;
    reg [0:0] sel5_in ;
    reg [0:0] sel9_in ;
    reg [0:0] sel1_in ;
    reg [0:0] sel3_in ;
    reg [0:0] sel6_in ;
    reg [0:0] sel0_in ;
    reg [0:0] sel4_in ;
    reg [0:0] sel2_in ;
    reg [0:0] in7_in ;
    reg [0:0] sel10_in ;
    reg [0:0] in0_in ;
    reg [0:0] sel7_in ;
    reg [0:0] in4_in ;
    reg [0:0] in1_in ;
    reg [0:0] in11_in ;
    reg [0:0] in10_in ;
    reg [0:0] in2_in ;
    reg [0:0] sel8_in ;
    reg [0:0] sel11_in ;
    reg [0:0] in3_in ;
    reg [0:0] in6_in ;
    wire [0:0] out_gold ;
    wire [0:0] out_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    oh_mux12_gold gold (
        .in5( in5_in ),
        .in8( in8_in ),
        .in9( in9_in ),
        .sel5( sel5_in ),
        .sel9( sel9_in ),
        .sel1( sel1_in ),
        .sel3( sel3_in ),
        .sel6( sel6_in ),
        .sel0( sel0_in ),
        .sel4( sel4_in ),
        .sel2( sel2_in ),
        .in7( in7_in ),
        .sel10( sel10_in ),
        .in0( in0_in ),
        .sel7( sel7_in ),
        .in4( in4_in ),
        .in1( in1_in ),
        .in11( in11_in ),
        .in10( in10_in ),
        .in2( in2_in ),
        .sel8( sel8_in ),
        .sel11( sel11_in ),
        .in3( in3_in ),
        .in6( in6_in ),
        .out( out_gold )
    );
    oh_mux12_gate gate (
        .in5( in5_in ),
        .in8( in8_in ),
        .in9( in9_in ),
        .sel5( sel5_in ),
        .sel9( sel9_in ),
        .sel1( sel1_in ),
        .sel3( sel3_in ),
        .sel6( sel6_in ),
        .sel0( sel0_in ),
        .sel4( sel4_in ),
        .sel2( sel2_in ),
        .in7( in7_in ),
        .sel10( sel10_in ),
        .in0( in0_in ),
        .sel7( sel7_in ),
        .in4( in4_in ),
        .in1( in1_in ),
        .in11( in11_in ),
        .in10( in10_in ),
        .in2( in2_in ),
        .sel8( sel8_in ),
        .sel11( sel11_in ),
        .in3( in3_in ),
        .in6( in6_in ),
        .out( out_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( out_gold === out_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            in5_in = {$random(seed)};
            in8_in = {$random(seed)};
            in9_in = {$random(seed)};
            sel5_in = {$random(seed)};
            sel9_in = {$random(seed)};
            sel1_in = {$random(seed)};
            sel3_in = {$random(seed)};
            sel6_in = {$random(seed)};
            sel0_in = {$random(seed)};
            sel4_in = {$random(seed)};
            sel2_in = {$random(seed)};
            in7_in = {$random(seed)};
            sel10_in = {$random(seed)};
            in0_in = {$random(seed)};
            sel7_in = {$random(seed)};
            in4_in = {$random(seed)};
            in1_in = {$random(seed)};
            in11_in = {$random(seed)};
            in10_in = {$random(seed)};
            in2_in = {$random(seed)};
            sel8_in = {$random(seed)};
            sel11_in = {$random(seed)};
            in3_in = {$random(seed)};
            in6_in = {$random(seed)};
        end
    endtask

    
    // Task to count errors
    task count_errors;
        begin
            if (trigger === 1'b1) begin
                num_errors = num_errors + 1;
            end
            num_all = num_all + 1;
        end
    endtask

    // initial block for random tests and targed tests
    initial begin
        if (!$value$plusargs("seed=%d", seed)) seed = 0;
        if (!$value$plusargs("outerLoopNum=%d", outerLoopNum)) outerLoopNum = 100;
        if (!$value$plusargs("innerLoopNum=%d", innerLoopNum)) innerLoopNum = 1000;
    
        repeat (outerLoopNum) begin
    
            #100; count_errors;
            repeat (innerLoopNum) begin
                #100; randomize_inputs;
    
                #100; count_errors;
            end
        end
        $display("Number of all tests:  %d", num_all);
        $display("Number of errors:     %d", num_errors);
        $display("Error rate: %.8f", num_errors/num_all);
        if (num_errors == 0) begin
            $display("All tests passed.");
        end
        $finish;
    end
endmodule
