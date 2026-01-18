`ifndef _pg2_v_
`define _pg2_v_
`endif
module pg2_gold(cin,c,p,g);
  input [1:0] p,g;
  input cin;
  output [2:1] c;
  wire [1:0] p,g;
  wire cin;
  wire [2:1] c;
  assign c[1] = g[0] | (p[0] & cin);
  assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
endmodule


module testbench;
    reg [1:0] p_in ;
    reg [0:0] cin_in ;
    reg [1:0] g_in ;
    wire [1:0] c_gold ;
    wire [1:0] c_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    pg2_gold gold (
        .p( p_in ),
        .cin( cin_in ),
        .g( g_in ),
        .c( c_gold )
    );
    pg2_gate gate (
        .p( p_in ),
        .cin( cin_in ),
        .g( g_in ),
        .c( c_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( c_gold === c_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            p_in = {$random(seed)};
            cin_in = {$random(seed)};
            g_in = {$random(seed)};
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
