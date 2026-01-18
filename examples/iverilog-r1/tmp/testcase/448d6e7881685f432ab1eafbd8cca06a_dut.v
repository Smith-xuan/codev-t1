module GrayToBinary #(
    parameter WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input wire inStrobe,
    input wire [WIDTH-1:0] dataIn,
    output reg outStrobe,
    output reg [WIDTH-1:0] dataOut
);

    // Combinational Gray-to-Binary conversion using XOR chain.
    // Gray code to binary conversion formula:
    //   binary[MSB] = Gray[MSB]
    //   binary[i] = binary[i+1] ^ Gray[i]  for i = MSB-1 downto 0
    wire [WIDTH-1:0] bin_comb;
    assign bin_comb[WIDTH-1] = dataIn[WIDTH-1];
    genvar i;
    generate
        for (i = WIDTH-2; i >= 0; i = i-1) begin : gray_to_bin
            assign bin_comb[i] = bin_comb[i+1] ^ dataIn[i];
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            dataOut <= 0;
            outStrobe <= 0;
        end else begin
            // Capture the converted value only when input is valid
            if (inStrobe) begin
                dataOut <= bin_comb;
            end
            // Output strobe is asserted one cycle after input strobe
            // indicating that dataOut is valid and corresponds to the
            // Gray input presented on the previous cycle.
            outStrobe <= inStrobe;
        end
    end

endmodule