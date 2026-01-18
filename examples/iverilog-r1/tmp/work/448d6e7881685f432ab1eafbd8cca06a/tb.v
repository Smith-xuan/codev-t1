module GrayToBinary_gold #(
    parameter WIDTH = 32
)
(
    input                  clk,
    input                  rst,
    input                  inStrobe,
    input      [WIDTH-1:0] dataIn,
    output reg             outStrobe,
    output reg [WIDTH-1:0] dataOut
);
parameter SHIFT_NUM = $clog2(WIDTH);
reg [WIDTH-1:0] shiftProducts [SHIFT_NUM-1:0];
integer i;
always @(*) begin
    shiftProducts[0] = dataIn ^ (dataIn >> (1 << (SHIFT_NUM-1)));
    for (i=1; i<SHIFT_NUM; i=i+1) begin
        shiftProducts[i] = shiftProducts[i-1]
                         ^ (shiftProducts[i-1] >> (1 << (SHIFT_NUM-1-i)));
    end
end
always @(posedge clk) begin
    if (rst) begin
        outStrobe <= 1'b0;
        dataOut   <= 'd0;
    end
    else begin
        outStrobe <= inStrobe;
        if (inStrobe) begin
            dataOut <= shiftProducts[SHIFT_NUM-1];
        end
    end
end
endmodule


module testbench;
    reg [31:0] dataIn_in ;
    reg [0:0] inStrobe_in ;
    reg [0:0] rst_in ;
    reg [0:0] clk_in ;
    wire [31:0] dataOut_gold ;
    wire [0:0] outStrobe_gold ;
    wire [31:0] dataOut_gate ;
    wire [0:0] outStrobe_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    GrayToBinary_gold gold (
        .dataIn( dataIn_in ),
        .inStrobe( inStrobe_in ),
        .rst( rst_in ),
        .clk( clk_in ),
        .dataOut( dataOut_gold ),
        .outStrobe( outStrobe_gold )
    );
    GrayToBinary_gate gate (
        .dataIn( dataIn_in ),
        .inStrobe( inStrobe_in ),
        .rst( rst_in ),
        .clk( clk_in ),
        .dataOut( dataOut_gate ),
        .outStrobe( outStrobe_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( dataOut_gold === dataOut_gate & outStrobe_gold === outStrobe_gate & 1'b1 );
    end

    // Task to toggle clk_in
    task toggle_clock;
        begin
            clk_in = ~clk_in ;
        end
    endtask

    task reset_0;
        begin
            rst_in = 1;
            # 10; toggle_clock; # 10; toggle_clock;
            rst_in = 0;
        end
    endtask

    // Task for random reset
    task random_reset;
        begin
            rst_in = $random(seed);
        end
    endtask

    // task to generate random inputs
    task randomize_inputs;
        begin
            dataIn_in = {$random(seed)};
            inStrobe_in = {$random(seed)};
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
        clk_in = 0;
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
