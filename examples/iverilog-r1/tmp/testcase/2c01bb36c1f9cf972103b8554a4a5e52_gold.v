module altera_up_avalon_video_lt24_write_sequencer (clk, reset, wait_sig, wrx);
// Inputs
input clk;
input reset;
input wait_sig;
// Outputs
output wrx;
// States
localparam	WAIT	= 3'b0001,
				SETUP = 3'b0010,
				LATCH = 3'b0100;
// State Machine Registers
reg	[2:0] ns_mode;
reg	[2:0] s_mode;
always @(posedge clk) // sync reset
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
// Output Assignments
assign wrx = (s_mode == SETUP) ? 1'b0 : 1'b1;
endmodule