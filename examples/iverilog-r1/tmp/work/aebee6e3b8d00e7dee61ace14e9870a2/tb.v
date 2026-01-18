module CRA64_gold (X,Y,Z,S,ZR,C,P,O);
input[63:0] X,Y;
output[63:0] Z;
output S,C,ZR,P,O;
wire c[15:1];
assign S = Z[63];
assign ZR = ~|Z;
assign P = ~^Z;
assign O =(X[63]&Y[63]&~Z[63])|(~X[63]&~Y[63]&Z[63]);
adder_4_gold A0(Z[3:0],c[1],X[3:0],Y[3:0],1'b0);
adder_4_gold A1(Z[7:4],c[2],X[7:4],Y[7:4],c[1]);
adder_4_gold A2(Z[11:8],c[3],X[11:8],Y[11:8],c[2]);
adder_4_gold A3(Z[15:12],c[4],X[15:12],Y[15:12],c[3]);
adder_4_gold A4(Z[19:16],c[5],X[19:16],Y[19:16],c[4]);
adder_4_gold A5(Z[23:20],c[6],X[23:20],Y[23:20],c[5]);
adder_4_gold A6(Z[27:24],c[7],X[27:24],Y[27:24],c[6]);
adder_4_gold A7(Z[31:28],c[8],X[31:28],Y[31:28],c[7]);
adder_4_gold A8(Z[35:32],c[9],X[35:32],Y[35:32],c[8]);
adder_4_gold A9(Z[39:36],c[10],X[39:36],Y[39:36],c[9]);
adder_4_gold A10(Z[43:40],c[11],X[43:40],Y[43:40],c[10]);
adder_4_gold A11(Z[47:44],c[12],X[47:44],Y[47:44],c[11]);
adder_4_gold A12(Z[51:48],c[13],X[51:48],Y[51:48],c[12]);
adder_4_gold A13(Z[55:52],c[14],X[55:52],Y[55:52],c[13]);
adder_4_gold A14(Z[59:56],c[15],X[59:56],Y[59:56],c[14]);
adder_4_gold A15(Z[63:60],C,X[63:60],Y[63:60],c[15]);
endmodule
module adder_4_gold (S,cout,A,B,cin);
input[3:0] A,B;
input cin;
output cout;
output [3:0] S;
assign {cout,S} = A + B + cin;
endmodule


module testbench;
    reg [63:0] X_in ;
    reg [63:0] Y_in ;
    wire [0:0] S_gold ;
    wire [0:0] P_gold ;
    wire [0:0] C_gold ;
    wire [0:0] ZR_gold ;
    wire [63:0] Z_gold ;
    wire [0:0] O_gold ;
    wire [0:0] S_gate ;
    wire [0:0] P_gate ;
    wire [0:0] C_gate ;
    wire [0:0] ZR_gate ;
    wire [63:0] Z_gate ;
    wire [0:0] O_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    CRA64_gold gold (
        .X( X_in ),
        .Y( Y_in ),
        .S( S_gold ),
        .P( P_gold ),
        .C( C_gold ),
        .ZR( ZR_gold ),
        .Z( Z_gold ),
        .O( O_gold )
    );
    CRA64_gate gate (
        .X( X_in ),
        .Y( Y_in ),
        .S( S_gate ),
        .P( P_gate ),
        .C( C_gate ),
        .ZR( ZR_gate ),
        .Z( Z_gate ),
        .O( O_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( S_gold === S_gate & P_gold === P_gate & C_gold === C_gate & ZR_gold === ZR_gate & Z_gold === Z_gate & O_gold === O_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            X_in = {$random(seed), $random(seed)};
            Y_in = {$random(seed), $random(seed)};
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
