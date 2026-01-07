module IFIDReg_gate (
    input wire clkIn,
    input wire resetn,
    input wire [31:0] AddrIn,
    input wire [31:0] InsIn,
    output reg [31:0] AddrOut,
    output reg [31:0] InsOut
);
always @(posedge clkIn or negedge resetn) begin
    if (!resetn) begin
        AddrOut <= 32'b0;
        InsOut <= 32'b0;
    end else begin
        AddrOut <= AddrIn;
        InsOut <= InsIn;
    end
end
endmodule