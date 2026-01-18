module control_unit_gate (
    input [4:0] opcode,
    input [4:0] rd,
    output reg [4:0] write_reg,
    output reg write_en
);
    localparam [4:0] OP_JAL   = 5'b00011;
    localparam [4:0] OP_SETX  = 5'b10101;
    localparam [4:0] OP_J     = 5'b00001;
    localparam [4:0] OP_BNE   = 5'b00010;
    localparam [4:0] OP_JR    = 5'b00100;
    localparam [4:0] OP_BLT   = 5'b00110;
    localparam [4:0] OP_SW    = 5'b00111;
    localparam [4:0] OP_BEX   = 5'b10110;
    localparam [4:0] R31      = 5'b11111;
    localparam [4:0] RSTATUS  = 5'b11110;
    always @(*) begin
        write_en = 1'b0;
        write_reg = 5'b0;
        case (opcode)
            OP_JAL: begin
                write_en = 1'b1;
                write_reg = R31;
            end
            OP_SETX: begin
                write_en = 1'b1;
                write_reg = RSTATUS;
            end
            OP_J,
            OP_BNE,
            OP_JR,
            OP_BLT,
            OP_SW,
            OP_BEX: begin
                write_en = 1'b0;
                write_reg = 5'b0;
            end
            default: begin
                if (rd != 5'b00000) begin
                    write_en = 1'b1;
                    write_reg = rd;
                end
            end
        endcase
    end
endmodule