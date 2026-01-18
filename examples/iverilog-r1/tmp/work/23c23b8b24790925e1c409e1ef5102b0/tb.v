module clocked_Sr_latch_gold(enable, set, reset, q_out,q_bar);
input enable, set, reset;
output q_out, q_bar;
 wire i, j;
  nand obj(i,enable,set);
  nand obj1(j,enable,reset);
  nand obj2(q_bar,j,q_out);
  nand obj3(q_out,i,q_bar);
endmodule


module testbench;
    reg [0:0] enable_in ;
    reg [0:0] reset_in ;
    reg [0:0] set_in ;
    wire [0:0] q_out_gold ;
    wire [0:0] q_bar_gold ;
    wire [0:0] q_out_gate ;
    wire [0:0] q_bar_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    clocked_Sr_latch_gold gold (
        .enable( enable_in ),
        .reset( reset_in ),
        .set( set_in ),
        .q_out( q_out_gold ),
        .q_bar( q_bar_gold )
    );
    clocked_Sr_latch_gate gate (
        .enable( enable_in ),
        .reset( reset_in ),
        .set( set_in ),
        .q_out( q_out_gate ),
        .q_bar( q_bar_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( q_out_gold === q_out_gate & q_bar_gold === q_bar_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            enable_in = {$random(seed)};
            reset_in = {$random(seed)};
            set_in = {$random(seed)};
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
