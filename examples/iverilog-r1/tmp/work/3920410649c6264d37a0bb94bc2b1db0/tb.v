module posedge_detector_gold (
    input wire clk,
    input wire signal,
    output wire posedge_detected
);
    reg signal_prev;
    always @(posedge clk) begin
        signal_prev <= signal;
    end
    assign posedge_detected = (signal == 1'b1) && (signal_prev == 1'b0);
endmodule


module testbench;
    reg [0:0] clk_in ;
    reg [0:0] signal_in ;
    wire [0:0] posedge_detected_gold ;
    wire [0:0] posedge_detected_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    posedge_detector_gold gold (
        .clk( clk_in ),
        .signal( signal_in ),
        .posedge_detected( posedge_detected_gold )
    );
    posedge_detector_gate gate (
        .clk( clk_in ),
        .signal( signal_in ),
        .posedge_detected( posedge_detected_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( posedge_detected_gold === posedge_detected_gate & 1'b1 );
    end

    // Task to toggle clk_in
    task toggle_clock;
        begin
            clk_in = ~clk_in ;
        end
    endtask

    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            signal_in = {$random(seed)};
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
