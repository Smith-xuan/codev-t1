
module rs_latch_gold (s, r, q, qn);
	input r, s;
	output q, qn;
	nand nand1 (q, s, qn);
	nand nand2 (qn, r, q);
endmodule


module testbench;
    reg [0:0] s_in ;
    reg [0:0] r_in ;
    wire [0:0] qn_gold ;
    wire [0:0] q_gold ;
    wire [0:0] qn_gate ;
    wire [0:0] q_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    rs_latch_gold gold (
        .s( s_in ),
        .r( r_in ),
        .qn( qn_gold ),
        .q( q_gold )
    );
    rs_latch_gate gate (
        .s( s_in ),
        .r( r_in ),
        .qn( qn_gate ),
        .q( q_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( qn_gold === qn_gate & q_gold === q_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            s_in = {$random(seed)};
            r_in = {$random(seed)};
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
