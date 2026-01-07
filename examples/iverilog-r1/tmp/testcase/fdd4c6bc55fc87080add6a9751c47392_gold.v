module Bin2BCD_2(binary, tens, ones);
input [7:0] binary;
output [3:0] tens;
output [3:0] ones;
reg [3:0] tens;
reg [3:0] ones;
integer i;
always @ (binary)
begin
	//set 10's and 1's to 0
	tens = 0;
	ones = 0;
for (i= 7; i>=0; i=i-1)
	begin
		//add 3 to columns >= 5
		if (tens >= 5)
		tens = tens+ 3;
		if (ones >= 5)
		ones = ones + 3;
		//shift left one
		tens = tens << 1;
		tens[0] = ones[3];
		ones = ones << 1;
		ones[0] = binary[i];
   end
end
endmodule