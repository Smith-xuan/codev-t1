module Alarm_gold(
	input clk,
	input alarm,
	output reg led,
	output reg buzzer
	);
	parameter CLK_DIV_PERIDO=8000;
	parameter LED_COUNT=1000;
	reg [15:0] cnt=0;
	reg [13:0] led_cnt=0;
	reg clk_div=0;
	always@(posedge clk)begin
		if(cnt>=(CLK_DIV_PERIDO-1)) begin
			cnt<=1'b0;
			clk_div=~clk_div;
		end else cnt<=cnt+1'b1;
	end
	always@(posedge clk_div) begin
		if(alarm)
			begin
				if(led_cnt>=(LED_COUNT-1)) begin led<=~led; led_cnt<=0;end
				else led_cnt<=led_cnt+1'b1;
				buzzer<=~buzzer;
			end
		else
			begin
				led<=1'b0;
				buzzer<=1'b1;
			end
	end
endmodule


module testbench;
    reg [0:0] clk_in ;
    reg [0:0] alarm_in ;
    wire [0:0] led_gold ;
    wire [0:0] buzzer_gold ;
    wire [0:0] led_gate ;
    wire [0:0] buzzer_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    Alarm_gold gold (
        .clk( clk_in ),
        .alarm( alarm_in ),
        .led( led_gold ),
        .buzzer( buzzer_gold )
    );
    Alarm_gate gate (
        .clk( clk_in ),
        .alarm( alarm_in ),
        .led( led_gate ),
        .buzzer( buzzer_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( led_gold === led_gate & buzzer_gold === buzzer_gate & 1'b1 );
    end

    // Task to toggle clk_in
    task toggle_clock;
        begin
            clk_in = ~clk_in ;
        end
    endtask

    task reset_0;
        begin
            alarm_in = 0;
            # 10; toggle_clock; # 10; toggle_clock;
            alarm_in = 1;
        end
    endtask

    // Task for random reset
    task random_reset;
        begin
            alarm_in = $random(seed);
        end
    endtask

    // task to generate random inputs
    task randomize_inputs;
        begin
            
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
