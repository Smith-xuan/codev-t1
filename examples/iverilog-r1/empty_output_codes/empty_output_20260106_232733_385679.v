// Verilog code that resulted in empty output
// Saved at: 2026-01-06T23:27:33.385715
// 
// Metadata:
//   status: success
//   api_status: Success
//   compile_status: Finished
//   run_status: Finished
//   compile_stderr: N/A
//   stdout: N/A
//   stderr: N/A
//   exit_code: 0
//
// Full metadata (JSON):
{
  "case_index": 0,
  "input": "",
  "expected_output": null,
  "api_request_error": null,
  "api_response": {
    "status": "Success",
    "message": "",
    "compile_result": {
      "status": "Finished",
      "return_code": 0,
      "stdout": "",
      "stderr": "",
      "execution_time": 0.0
    },
    "run_result": {
      "status": "Finished",
      "return_code": 0,
      "stdout": "",
      "stderr": "",
      "execution_time": 0.0
    },
    "files": {}
  },
  "status": "success",
  "stdout": "",
  "stderr": "",
  "exit_code": 0,
  "duration": 0.0,
  "compile_duration": 0.0,
  "compile_stderr": "",
  "api_status": "Success",
  "compile_status": "Finished",
  "run_status": "Finished"
}

// ============================================================================
// Verilog Code:
// ============================================================================

module Bin2BCDConverter_4 #(parameter WIDTH=8) (
    input wire [WIDTH-1:0] Input,
    output wire [3:0] Digit3, Digit2, Digit1, Digit0
);

    // Compute number of BCD digits needed: at least ceil(WIDTH/3), but at least 4
    localparam D = (WIDTH > 9) ? (WIDTH + 2) / 3 : 4;
    localparam BCD_WIDTH = D * 4;

    reg [BCD_WIDTH-1:0] bcd;
    integer i, j;

    always @(*) begin
        // Initialize BCD register to zero
        bcd = {BCD_WIDTH{1'b0}};
        // Process each input bit from LSB to MSB
        for (i = 0; i < WIDTH; i = i + 1) begin
            // Shift BCD left by 1, insert current input bit at LSB
            bcd = (bcd << 1) | Input[i];
            // Check each BCD digit from most significant to least significant
            for (j = D-1; j >= 0; j = j - 1) begin
                // Extract the 4-bit digit
                if (bcd[j*4 +: 4] >= 5) begin
                    // Add 3 to the digit
                    bcd[j*4 +: 4] = bcd[j*4 +: 4] + 3;
                end
            end
        end
    end

    // Map the BCD digits to outputs. If D < 4, pad with zeros.
    // Digit3 = thousands, Digit2 = hundreds, Digit1 = tens, Digit0 = units
    assign Digit3 = (D >= 3) ? bcd[12 +: 4] : 4'b0;
    assign Digit2 = (D >= 2) ? bcd[8 +: 4] : 4'b0;
    assign Digit1 = (D >= 1) ? bcd[4 +: 4] : 4'b0;
    assign Digit0 = bcd[0 +: 4];

endmodule

module testbench;
    reg [7:0] Input;
    wire [3:0] Digit3, Digit2, Digit1, Digit0;
    
    // Instantiate DUT
    Bin2BCDConverter_4 #(.WIDTH(8)) dut (.Input(Input), .Digit3(Digit3), .Digit2(Digit2), .Digit1(Digit1), .Digit0(Digit0));
    
    // Helper function to print BCD digits
    function print_bcd;
        input [3:0] d3, d2, d1, d0;
        begin
            $write(" %d%d%d%d", d3, d2, d1, d0);
        end
    endfunction
    
    reg [15:0] debug_bcd;
    assign debug_bcd = {dut.Digit3, dut.Digit2, dut.Digit1, dut.Digit0}; // This won't work because Digit3 etc are not module items
    // Instead, we can't access internal signals directly. Let's instantiate the module and use hierarchical reference.
    // But we can't access bcd as it's a reg. However we can add a temporary port for debugging.
    // Let's create a wrapper.
    
endmodule
