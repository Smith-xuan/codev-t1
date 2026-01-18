module write_regfile_control_gold(opcode, rd, write_reg, write_en);
        input  [4:0] opcode;
        input  [4:0] rd;
        output [4:0] write_reg;
        output write_en;
    wire jal_check, setx_check, rd_check;
    assign jal_check = (
        ~opcode[4] && ~opcode[3] && ~opcode[2] && opcode[1] && opcode[0]
    ) ? 1'b1 : 1'b0;
    assign setx_check = (
        opcode[4] && ~opcode[3] && opcode[2] && ~opcode[1] && opcode[0]
    ) ? 1'b1 : 1'b0;
    assign rd_check = (~jal_check && ~setx_check);
    assign write_reg = jal_check  ? 5'b11111 : 5'bzzzzz;
    assign write_reg = setx_check ? 5'b11110 : 5'bzzzzz;
    assign write_reg = rd_check   ? rd       : 5'bzzzzz;
    wire j_check, bne_check, jr_check, blt_check, sw_check, bex_check;
	assign j_check = (
		~opcode[4] && ~opcode[3] && ~opcode[2] && ~opcode[1] && opcode[0]
	) ? 1'b1 : 1'b0;
	assign bne_check = (
		~opcode[4] && ~opcode[3] && ~opcode[2] && opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	assign jr_check = (
		~opcode[4] && ~opcode[3] && opcode[2] && ~opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	assign blt_check = (
		~opcode[4] && ~opcode[3] && opcode[2] && opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	assign sw_check = (
		~opcode[4] && ~opcode[3] && opcode[2] && opcode[1] && opcode[0]
	) ? 1'b1 : 1'b0;
	assign bex_check = (
		opcode[4] && ~opcode[3] && opcode[2] && opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	assign nop_check = (
		~rd[4] && ~rd[3] && ~rd[2] && ~rd[1] && ~rd[0] &&
        ~jal_check && ~setx_check
	) ? 1'b1 : 1'b0;
    wire disable_writing;
    assign disable_writing = j_check   || bne_check || jr_check  ||
                             blt_check || sw_check  || bex_check ||
									  nop_check;
    assign write_en = disable_writing ? 1'b0 : 1'b1;
endmodule


module testbench;
    reg [4:0] rd_in ;
    reg [4:0] opcode_in ;
    wire [4:0] write_reg_gold ;
    wire [0:0] write_en_gold ;
    wire [4:0] write_reg_gate ;
    wire [0:0] write_en_gate ;

    reg trigger;
    real num_all = 0;
    real num_errors = 0;
    integer seed;
    integer outerLoopNum;
    integer innerLoopNum;

    write_regfile_control_gold gold (
        .rd( rd_in ),
        .opcode( opcode_in ),
        .write_reg( write_reg_gold ),
        .write_en( write_en_gold )
    );
    control_unit_gate gate (
        .rd( rd_in ),
        .opcode( opcode_in ),
        .write_reg( write_reg_gate ),
        .write_en( write_en_gate )
    );
    
    always @(*) begin
        #5; trigger = ~( write_reg_gold === write_reg_gate & write_en_gold === write_en_gate & 1'b1 );
    end

    
    
    
    // task to generate random inputs
    task randomize_inputs;
        begin
            rd_in = {$random(seed)};
            opcode_in = {$random(seed)};
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
