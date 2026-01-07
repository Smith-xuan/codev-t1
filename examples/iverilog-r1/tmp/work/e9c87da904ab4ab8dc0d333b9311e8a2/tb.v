`timescale 1ns / 1ps
module IFIDReg_gold(clkIn,resetn,AddrIn,AddrOut,InsIn,InsOut);
input clkIn;
input resetn;
input [31:0]AddrIn;
input [31:0]InsIn;
output reg [31:0] AddrOut;
output reg [31:0] InsOut;
always @(posedge clkIn) begin
   if(~resetn)begin
      InsOut<=32'b0;
      AddrOut<=32'b0;
   end
   else begin
       AddrOut<=AddrIn;
       InsOut<=InsIn;
   end
end
endmodule


module testbench;
    reg [31:0] InsIn_in ;
    reg [31:0] AddrIn_in ;
    reg [0:0] resetn_in ;
    reg [0:0] clkIn_in ;
    wire [31:0] AddrOut_gold ;
    wire [31:0] InsOut_gold ;
    wire [31:0] AddrOut_gate ;
    wire [31:0] InsOut_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    IFIDReg_gold gold (
        .InsIn( InsIn_in ),
        .AddrIn( AddrIn_in ),
        .resetn( resetn_in ),
        .clkIn( clkIn_in ),
        .AddrOut( AddrOut_gold ),
        .InsOut( InsOut_gold )
    );
    IFIDReg_gate gate (
        .InsIn( InsIn_in ),
        .AddrIn( AddrIn_in ),
        .resetn( resetn_in ),
        .clkIn( clkIn_in ),
        .AddrOut( AddrOut_gate ),
        .InsOut( InsOut_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( AddrOut_gold === AddrOut_gate & InsOut_gold === InsOut_gate & 1'b1 );
    end

    // Task to toggle clkIn_in
    task toggle_clock;
        begin
            clkIn_in = ~clkIn_in ;
        end
    endtask

    task reset_0;
        begin
            resetn_in = 0;
            # 10; toggle_clock; # 10; toggle_clock;
            resetn_in = 1;
        end
    endtask

    // Task for random reset
    task random_reset;
        begin
            resetn_in = $random(seed);
        end
    endtask

    // task to generate random inputs
    task randomize_inputs;
        begin
            InsIn_in = {$random(seed)};
            AddrIn_in = {$random(seed)};
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
        clkIn_in = 0;
        repeat (outerLoopNum) begin
            random_reset;
            #100; count_errors;
            repeat (innerLoopNum) begin
                #100; randomize_inputs;
                #100; toggle_clock;
                #100; count_errors;
            end
        end
        #100;
        repeat (outerLoopNum) begin
            reset_0;
            #100; count_errors;
            repeat (innerLoopNum) begin
                #100; randomize_inputs;
                #100; toggle_clock;
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
