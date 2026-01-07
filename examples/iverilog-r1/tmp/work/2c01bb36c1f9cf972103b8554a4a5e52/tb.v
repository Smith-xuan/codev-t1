module altera_up_avalon_video_lt24_write_sequencer_gold (clk, reset, wait_sig, wrx);
input clk;
input reset;
input wait_sig;
output wrx;
localparam	WAIT	= 3'b0001,
				SETUP = 3'b0010,
				LATCH = 3'b0100;
reg	[2:0] ns_mode;
reg	[2:0] s_mode;
always @(posedge clk)
begin
	if (reset == 1'b1)
		s_mode <= WAIT;
	else
		s_mode <= ns_mode;
end
always @(*)
begin
	case (s_mode)
		WAIT:
		begin
			if (wait_sig == 1'b1)
				ns_mode <= WAIT;
			else
				ns_mode <= SETUP;
		end
		SETUP:
		begin
			ns_mode <= LATCH;
		end
		LATCH:
		begin
			if (wait_sig == 1'b1)
				ns_mode <= WAIT;
			else
				ns_mode <= SETUP;
		end
		default:
		begin
			ns_mode <= WAIT;
		end
	endcase
end
assign wrx = (s_mode == SETUP) ? 1'b0 : 1'b1;
endmodule


module testbench;
    reg [0:0] reset_in ;
    reg [0:0] wait_sig_in ;
    reg [0:0] clk_in ;
    wire [0:0] wrx_gold ;
    wire [0:0] wrx_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    altera_up_avalon_video_lt24_write_sequencer_gold gold (
        .reset( reset_in ),
        .wait_sig( wait_sig_in ),
        .clk( clk_in ),
        .wrx( wrx_gold )
    );
    altera_up_avalon_video_lt24_write_sequencer_gate gate (
        .reset( reset_in ),
        .wait_sig( wait_sig_in ),
        .clk( clk_in ),
        .wrx( wrx_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( wrx_gold === wrx_gate & 1'b1 );
    end

    // Task to toggle clk_in
    task toggle_clock;
        begin
            clk_in = ~clk_in ;
        end
    endtask

    task reset_0;
        begin
            reset_in = 1;
            # 10; toggle_clock; # 10; toggle_clock;
            reset_in = 0;
        end
    endtask

    // Task for random reset
    task random_reset;
        begin
            reset_in = $random(seed);
        end
    endtask

    // task to generate random inputs
    task randomize_inputs;
        begin
            wait_sig_in = {$random(seed)};
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
