// Verilog code that resulted in empty output
// Saved at: 2026-01-05T20:58:57.353041
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

module MUX #(parameter S_WIDTH = 3) (
    input [S_WIDTH-1:0] s,          // control signal width: 1,2, or 3
    input [31:0] d0, d1, d2, d3, d4, d5, d6, d7,  // up to eight 32‑bit inputs
    output reg [31:0] data_o        // selected 32‑bit data
);

    // Combinational multiplexer with default zero for out‑of‑range select values
    always @(*) begin
        case (s)
            4'd0: data_o = d0;
            4'd1: data_o = d1;
            4'd2: data_o = d2;
            4'd3: data_o = d3;
            4'd4: data_o = d4;
            4'd5: data_o = d5;
            4'd6: data_o = d6;
            4'd7: data_o = d7;
            default: data_o = 32'b0;   // select value beyond number of valid inputs
        endcase
    end

endmodule

module testbench;
    // Test 1: S_WIDTH = 3
    reg [2:0] s;
    wire [31:0] out;
    MUX #(.S_WIDTH(3)) dut (.s(s), .d0(32'h0000000A), .d1(32'h11111111), 
                            .d2(32'h22222222), .d3(32'h33333333), 
                            .d4(32'h44444444), .d5(32'h55555555), 
                            .d6(32'h66666666), .d7(32'h77777777), .data_o(out));
    
    initial begin
        // Test each selector
        s = 0; #5; if (out !== 32'h0000000A) $display("FAIL s=0: got %h", out);
        s = 1; #5; if (out !== 32'h11111111) $display("FAIL s=1: got %h", out);
        s = 2; #5; if (out !== 32'h22222222) $display("FAIL s=2: got %h", out);
        s = 3; #5; if (out !== 32'h33333333) $display("FAIL s=3: got %h", out);
        s = 4; #5; if (out !== 32'h44444444) $display("FAIL s=4: got %h", out);
        s = 5; #5; if (out !== 32'h55555555) $display("FAIL s=5: got %h", out);
        s = 6; #5; if (out !== 32'h66666666) $display("FAIL s=6: got %h", out);
        s = 7; #5; if (out !== 32'h77777777) $display("FAIL s=7: got %h", out);
        // Out of range (though s is only 3 bits, 8 is binary 1000, but with 3 bits it's truncated to 0)
        // We'll test with a 4-bit value and connect as 3-bit? Let's just test with s=8 (4 bits) but we can't because port width is 3.
        // Instead we'll instantiate another DUT with different parameter.
    end
endmodule
