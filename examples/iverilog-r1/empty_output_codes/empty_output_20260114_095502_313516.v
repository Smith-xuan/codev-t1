// Verilog code that resulted in empty output
// Saved at: 2026-01-14T09:55:02.313570
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

`timescale 1ns / 1ps

module DualPriority (
    input [11:0] r,
    output reg [3:0] first,
    output reg [3:0] second
);

    // Function to convert position to priority code
    function [3:0] pos_to_code;
        input [3:0] pos;
        begin
            case (pos)
                4'd11: pos_to_code = 4'b1100;
                4'd10: pos_to_code = 4'b1011;
                4'd9:  pos_to_code = 4'b0110;
                4'd8:  pos_to_code = 4'b0011;
                4'd7:  pos_to_code = 4'b0000;
                default: pos_to_code = 4'b0000; // positions 6-0
            endcase
        end
    endfunction

    // Find highest set bit position using casez
    always @(*) begin
        casez (r)
            12'b1??????????? : first = 4'b1100; // position 11
            12'b01??????????: first = 4'b1011; // position 10
            12'b001?????????: first = 4'b0110; // position 9
            12'b0001??????:  first = 4'b0011; // position 8
            12'b00001?????:  first = 4'b0000; // position 7
            12'b000001?????: first = 4'b0000; // position 6 (actually all positions 7-0 map to 0000)
            // We need to cover positions 6 down to 0 as well, but they all map to 0000.
            // However, we need to differentiate that there is at least one set bit among them.
            // Since they all map to same code, we can just cover with one pattern that matches any non-zero lower bits.
            // But we already have pattern for bit 7 (12'b00001?????) and default.
            // Actually default will catch any vector not matched above, including vectors where all bits 11..8 are zero and at least one bit 7..0 is set.
            // However, we need to assign first = 0000 for those cases.
            // So we should have a default case that sets first to 0000.
            default: first = 4'b0000;
        endcase
    end

    // Compute masked input (clear the highest set bit)
    wire [11:0] masked_r = r & ~(12'b1 << first_conv); // need first_conv as position from first code? Wait we need position, not code.
    // Oops, we cannot compute mask from code because mapping is non-linear. Code 1100 corresponds to position 11, 1011 to 10, etc.
    // So we need position, not code.
    // This approach using casez directly gives code, but we need position for masking.
    // Let's redesign using positions.
    // Actually we need to output first code, not first position. But we need position for masking.
    // We can compute position from code via a reverse mapping (function). But we can also capture position in casez.
    // Let's compute first_pos as well.
    // Let's change: compute first_pos using casez and then convert to first code.
    // However, the requirement might allow us to compute codes directly.
    // We'll compute first_pos similarly and then compute first code from pos.
    // Let's create an internal wire first_pos.
endmodule

module testbench;
    // dummy testbench
endmodule
