module write_regfile_control(opcode, rd, write_reg, write_en); 
        input  [4:0] opcode;
        input  [4:0] rd;
        output [4:0] write_reg;
        output write_en;
    wire jal_check, setx_check, rd_check;
    // Write to $r31 when jal instruction (Opcode: 00011)
    assign jal_check = (
        ~opcode[4] && ~opcode[3] && ~opcode[2] && opcode[1] && opcode[0] 
    ) ? 1'b1 : 1'b0;
    // Write to $rstatus when setx instruction (Opcode: 10101)
    assign setx_check = (
        opcode[4] && ~opcode[3] && opcode[2] && ~opcode[1] && opcode[0] 
    ) ? 1'b1 : 1'b0;
    // Write to $rd in the normal case
    assign rd_check = (~jal_check && ~setx_check);
    assign write_reg = jal_check  ? 5'b11111 : 5'bzzzzz; 
    assign write_reg = setx_check ? 5'b11110 : 5'bzzzzz;
    assign write_reg = rd_check   ? rd       : 5'bzzzzz;
    wire j_check, bne_check, jr_check, blt_check, sw_check, bex_check;
    // Check if j instruction (Opcode: 00001)
	assign j_check = (
		~opcode[4] && ~opcode[3] && ~opcode[2] && ~opcode[1] && opcode[0]
	) ? 1'b1 : 1'b0;
	// Check if bne instruction (Opcode: 00010)
	assign bne_check = (
		~opcode[4] && ~opcode[3] && ~opcode[2] && opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	// Check if jr instruction (Opcode: 00100)
	assign jr_check = (
		~opcode[4] && ~opcode[3] && opcode[2] && ~opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	// Check if blt instruction (Opcode: 00110)
	assign blt_check = (
		~opcode[4] && ~opcode[3] && opcode[2] && opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	// Check if sw instruction (Opcode: 00111)
	assign sw_check = (
		~opcode[4] && ~opcode[3] && opcode[2] && opcode[1] && opcode[0]
	) ? 1'b1 : 1'b0;
	// Check if bex instruction (Opcode: 10110)
	assign bex_check = (
		opcode[4] && ~opcode[3] && opcode[2] && opcode[1] && ~opcode[0]
	) ? 1'b1 : 1'b0;
	// Edge Case: Check if $rd is 00000 and not doing jal or setx (indicates nop instruction)
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