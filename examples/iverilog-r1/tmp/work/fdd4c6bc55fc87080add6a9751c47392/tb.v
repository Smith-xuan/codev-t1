module Bin2BCD_2_gold(binary, tens, ones);
input [7:0] binary;
output [3:0] tens;
output [3:0] ones;
reg [3:0] tens;
reg [3:0] ones;
integer i;
always @ (binary)
begin
	tens = 0;
	ones = 0;
for (i= 7; i>=0; i=i-1)
	begin
		if (tens >= 5)
		tens = tens+ 3;
		if (ones >= 5)
		ones = ones + 3;
		tens = tens << 1;
		tens[0] = ones[3];
		ones = ones << 1;
		ones[0] = binary[i];
   end
end
endmodule


module testbench;
    reg [7:0] binary_in ;
    wire [3:0] ones_gold ;
    wire [3:0] tens_gold ;
    wire [3:0] ones_gate ;
    wire [3:0] tens_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    Bin2BCD_2_gold gold (
        .binary( binary_in ),
        .ones( ones_gold ),
        .tens( tens_gold )
    );
    Bin2BCD_2_gate gate (
        .binary( binary_in ),
        .ones( ones_gate ),
        .tens( tens_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( ones_gold === ones_gate & tens_gold === tens_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            binary_in = {$random(seed)};
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
