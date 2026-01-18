module control_unit (
    input [4:0] opcode,
    input [4:0] rd,
    output reg [4:0] write_reg,
    output reg write_en
);

    // Opcode definitions (as per specification)
    localparam [4:0] OP_JAL   = 5'b00011;
    localparam [4:0] OP_SETX  = 5'b10101;
    localparam [4:0] OP_J     = 5'b00001;
    localparam [4:0] OP_BNE   = 5'b00010;
    localparam [4:0] OP_JR    = 5'b00100;
    localparam [4:0] OP_BLT   = 5'b00110;
    localparam [4:0] OP_SW    = 5'b00111;
    localparam [4:0] OP_BEX   = 5'b10110;

    // Register numbers
    localparam [4:0] R31      = 5'b11111;      // $r31 is the link register for jal
    localparam [4:0] RSTATUS  = 5'b11110;      // $rstatus is a special status register

    always @(*) begin
        // Default assignments (prevents latches)
        write_en = 1'b0;
        write_reg = 5'b0;

        case (opcode)
            // Special instructions that always write to a fixed destination
            OP_JAL: begin
                // jal writes return address to $r31 regardless of rd field
                write_en = 1'b1;
                write_reg = R31;
            end
            OP_SETX: begin
                // setx writes something to $rstatus regardless of rd field
                write_en = 1'b1;
                write_reg = RSTATUS;
            end

            // Instructions that never perform a register write
            OP_J,
            OP_BNE,
            OP_JR,
            OP_BLT,
            OP_SW,
            OP_BEX: begin
                write_en = 1'b0;           // no write
                write_reg = 5'b0;           // don't care
            end

            // All other instructions (not listed above)
            default: begin
                // Check if rd is zero (special nop case)
                if (rd != 5'b00000) begin
                    // Normal write to the destination register specified by rd
                    write_en = 1'b1;
                    write_reg = rd;
                end
                // else rd == 0 -> treat as NOP (no write, rd don't care)
            end
        endcase
    end

endmodule