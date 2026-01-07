module IFIDReg (
    input wire clkIn,
    input wire resetn,
    input wire [31:0] AddrIn,
    input wire [31:0] InsIn,
    output reg [31:0] AddrOut,
    output reg [31:0] InsOut
);

// Asynchronous active-low reset with clocked capture
always @(posedge clkIn or negedge resetn) begin
    if (!resetn) begin
        // Clear outputs when reset is active (low)
        AddrOut <= 32'b0;
        InsOut <= 32'b0;
    end else begin
        // Capture inputs on rising clock edge
        AddrOut <= AddrIn;
        InsOut <= InsIn;
    end
end

endmodule