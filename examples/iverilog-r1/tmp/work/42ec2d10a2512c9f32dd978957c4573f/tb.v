module jkstruct_gold(j,k,clk,q,qbar);
input j,k,clk;
output q,qbar;
wire x,y,w,z;
assign w=q;
assign z=qbar;
nand n1(x,z,j,clk);
nand n2(y,k,w,clk);
nand n3(q,x,z);
nand n4(qbar,y,w);
endmodule


module testbench;
    reg [0:0] k_in ;
    reg [0:0] j_in ;
    reg [0:0] clk_in ;
    wire [0:0] q_gold ;
    wire [0:0] qbar_gold ;
    wire [0:0] q_gate ;
    wire [0:0] qbar_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    jkstruct_gold gold (
        .k( k_in ),
        .j( j_in ),
        .clk( clk_in ),
        .q( q_gold ),
        .qbar( qbar_gold )
    );
    jkstruct_gate gate (
        .k( k_in ),
        .j( j_in ),
        .clk( clk_in ),
        .q( q_gate ),
        .qbar( qbar_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( q_gold === q_gate & qbar_gold === qbar_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            k_in = {$random(seed)};
            j_in = {$random(seed)};
            clk_in = {$random(seed)};
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
