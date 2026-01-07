module Bin2BCD_8bits (
   input  wire [7:0] Bin,
   output wire [3:0] Least,
   output wire [3:0] Most
);
integer i;
reg  [7:0] itr [0:8];
reg  [7:0] temp;
reg  [7:0] BCD;
// Double Dabble algorithm
always @(*) begin 	
    for (i = 0;i < 9;i = i + 1) begin
        itr[i] = 8'b0;
    end
    i = 0;
    for (i = 0;i < 8;i = i + 1) begin
        itr[i+1][3:0] = (itr[i][3:0] >= 5)? (itr[i][3:0] + 3): itr[i][3:0];
        itr[i+1][7:4] = (itr[i][7:4] >= 5)? (itr[i][7:4] + 3): itr[i][7:4];
        temp          = itr[i+1];
        itr[i+1]      = {temp[6:0],Bin[7-i]}; 
    end
    BCD = itr[8];
end
assign {Most,Least} = BCD;
endmodule