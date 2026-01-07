// Verilog code that resulted in empty output
// Saved at: 2026-01-07T10:52:47.782626
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

module bitbrick (
    input [1:0] x,
    input s_x,
    input [1:0] y,
    input s_y,
    input [2:0] shift,
    output reg [9:0] prod
);

    // Extended inputs
    wire signed [4:0] x_ext;
    wire signed [4:0] y_ext;
    
    assign x_ext = s_x ? $signed({{3{x[1]}}, x}) : $signed({3'b0, x});
    assign y_ext = s_y ? $signed({{3{y[1]}}, y}) : $signed({3'b0, y});
    
    wire signed [9:0] product;
    assign product = x_ext * y_ext;
    
    wire signed [9:0] shifted;
    assign shifted = product << shift;
    
    always @* begin
        prod = shifted;
    end

endmodule

module testbench;
    reg [1:0] x;
    reg [1:0] y;
    reg s_x, s_y;
    reg [2:0] shift;
    wire [9:0] prod;
    
    bitbrick dut (x, s_x, y, s_y, shift, prod);
    
    // Reference calculation function
    function signed [9:0] reference_product;
        input [1:0] x;
        input s_x;
        input [1:0] y;
        input s_y;
        input [2:0] shift;
        reg signed [4:0] x_ext, y_ext;
        reg signed [9:0] prod_signed, shifted;
        begin
            if (s_x)
                x_ext = $signed({{3{x[1]}}, x});
            else
                x_ext = $signed({3'b0, x});
            if (s_y)
                y_ext = $signed({{3{y[1]}}, y});
            else
                y_ext = $signed({3'b0, y});
            prod_signed = x_ext * y_ext;
            shifted = prod_signed << shift;
            reference_product = shifted;
        end
    endfunction
    
    integer i, errors;
    reg [9:0] expected;
    
    initial begin
        errors = 0;
        for (i = 0; i < 256; i = i + 1) begin
            // Unpack i into inputs
            // bits: x[1], x[0], s_x, y[1], y[0], s_y, shift[2], shift[1], shift[0]
            // Actually we have 2+1+2+1+3 = 9 bits
            x = i[8:7]; // but we need to assign correctly
            // Let's define manually
            // i[8] = x[1]
            // i[7] = x[0]
            // i[6] = s_x
            // i[5] = y[1]
            // i[4] = y[0]
            // i[3] = s_y
            // i[2:0] = shift
            // So we need 9 bits, but i is 0-255 (8 bits). Let's use two loops.
        end
    end
endmodule
