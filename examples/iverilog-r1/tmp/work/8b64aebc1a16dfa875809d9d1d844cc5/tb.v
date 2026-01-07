module Bin2BCD_8bits_gold (
   input  wire [7:0] Bin,
   output wire [3:0] Least,
   output wire [3:0] Most
);
integer i;
reg  [7:0] itr [0:8];
reg  [7:0] temp;
reg  [7:0] BCD;
always @(*) begin
    for (i = 0;i < 9;i = i + 1) begin
        itr[i] = 8'b0;
    end
    i = 0;
    for (i = 0;i < 8;i = i + 1) begin
        itr[i+1][3:0] = (itr[i][3:0] >= 5)? (itr[i][3:0] + 3): itr[i][3:0];
        itr[i+1][7:4] = (itr[i][7:4] >= 5)? (itr[i][7:4] + 3): itr[i][7:4];
        temp          = itr[i+1];
        itr[i+1]      = {temp[6:0],Bin[7-i]};
    end
    BCD = itr[8];
end
assign {Most,Least} = BCD;
endmodule


module testbench;
    reg [7:0] Bin_in ;
    wire [3:0] Least_gold ;
    wire [3:0] Most_gold ;
    wire [3:0] Least_gate ;
    wire [3:0] Most_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    Bin2BCD_8bits_gold gold (
        .Bin( Bin_in ),
        .Least( Least_gold ),
        .Most( Most_gold )
    );
    Bin2BCD_8bits_gate gate (
        .Bin( Bin_in ),
        .Least( Least_gate ),
        .Most( Most_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( Least_gold === Least_gate & Most_gold === Most_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            Bin_in = {$random(seed)};
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
