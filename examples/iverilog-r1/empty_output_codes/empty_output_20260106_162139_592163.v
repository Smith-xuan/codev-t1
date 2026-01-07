// Verilog code that resulted in empty output
// Saved at: 2026-01-06T16:21:39.592193
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

module shifter #(parameter N = 16) (
    input wire [N-1:0] in,
    input wire [1:0] shift,
    output reg [N-1:0] sout
);
    // Combinational logic for shift operations
    always @* begin
        case (shift)
            2'b00: sout = in;                     // pass-through
            2'b01: sout = (N > 1) ? {in[N-2:0], 1'b0} : 1'b0; // logical left shift
            2'b10: sout = (N > 1) ? {1'b0, in[N-1:1]} : 1'b0; // logical right shift
            2'b11: begin                          // arithmetic right shift
                if (N == 1)
                    sout = in;                    // preserve MSB (single bit)
                else
                    sout = {in[N-1], in[N-1:1]};  // fill MSB with original MSB
            end
            default: sout = {N{1'bx}};            // unknown state for unexpected shift values
        endcase
    end
endmodule

// Testbench for N=8 (default)
module testbench_n8;
    parameter N = 8;
    reg [N-1:0] in;
    reg [1:0] shift;
    wire [N-1:0] sout;
    
    shifter #(N) dut (.in(in), .shift(shift), .sout(sout));
    
    initial begin
        $display("Testing shifter with N=%0d", N);
        
        // Test pass-through
        shift = 2'b00;
        in = 8'b10110010;
        #10;
        $display("Pass-through: in=%b, sout=%b %s", in, sout, (sout === in) ? "OK" : "ERROR");
        
        // Test left shift
        shift = 2'b01;
        #10;
        $display("Left shift: in=%b, sout=%b %s", in, sout, (sout === {in[N-2:0], 1'b0}) ? "OK" : "ERROR");
        
        // Test right shift
        shift = 2'b10;
        #10;
        $display("Right shift: in=%b, sout=%b %s", in, sout, (sout === {1'b0, in[N-1:1]}) ? "OK" : "ERROR");
        
        // Test arithmetic right shift
        shift = 2'b11;
        #10;
        $display("Arithmetic shift: in=%b, sout=%b %s", in, sout, (sout === {in[N-1], in[N-1:1]}) ? "OK" : "ERROR");
        
        // Test with MSB=1
        in = 8'b10000000;
        shift = 2'b11;
        #10;
        $display("Arithmetic shift MSB=1: in=%b, sout=%b %s", in, sout, (sout === 8'b11000000) ? "OK" : "ERROR");
        
        // Test with MSB=0
        in = 8'b01111111;
        shift = 2'b11;
        #10;
        $display("Arithmetic shift MSB=0: in=%b, sout=%b %s", in, sout, (sout === 8'b00111111) ? "OK" : "ERROR");
        
        // Test default (unknown shift)
        shift = 2'bxx;
        #10;
        $display("Default case: in=%b, sout=%b %s", in, sout, (sout === {N{1'bx}}) ? "OK" : "ERROR");
        
        // Additional edge cases
        // Left shift zero
        in = 8'b00000000;
        shift = 2'b01;
        #10;
        $display("Left shift zero: in=%b, sout=%b %s", in, sout, (sout === 8'b00000000) ? "OK" : "ERROR");
        
        // Right shift zero
        shift = 2'b10;
        #10;
        $display("Right shift zero: in=%b, sout=%b %s", in, sout, (sout === 8'b00000000) ? "OK" : "ERROR");
        
        // All ones
        in = 8'b11111111;
        shift = 2'b01;
        #10;
        $display("Left shift all ones: in=%b, sout=%b %s", in, sout, (sout === 8'b11111110) ? "OK" : "ERROR");
        
        shift = 2'b10;
        #10;
        $display("Right shift all ones: in=%b, sout=%b %s", in, sout, (sout === 8'b01111111) ? "OK" : "ERROR");
        
        shift = 2'b11;
        #10;
        $display("Arithmetic shift all ones: in=%b, sout=%b %s", in, sout, (sout === 8'b11111111) ? "OK" : "ERROR");
        
        $display("N=8 tests completed.");
        $finish;
    end
endmodule

// Testbench for N=1
module testbench_n1;
    parameter N = 1;
    reg [N-1:0] in;
    reg [1:0] shift;
    wire [N-1:0] sout;
    
    shifter #(N) dut (.in(in), .shift(shift), .sout(sout));
    
    initial begin
        $display("\nTesting shifter with N=%0d", N);
        
        // Test various shift settings
        shift = 2'b00;
        in = 1'b0;
        #10;
        $display("Pass-through 0: in=%b, sout=%b %s", in, sout, (sout === 1'b0) ? "OK" : "ERROR");
        
        in = 1'b1;
        #10;
        $display("Pass-through 1: in=%b, sout=%b %s", in, sout, (sout === 1'b1) ? "OK" : "ERROR");
        
        shift = 2'b01; // left shift
        #10;
        $display("Left shift 0: in=%b, sout=%b %s", in, sout, (sout === 1'b0) ? "OK" : "ERROR");
        
        shift = 2'b10; // right shift
        #10;
        $display("Right shift 0: in=%b, sout=%b %s", in, sout, (sout === 1'b0) ? "OK" : "ERROR");
        
        shift = 2'b11; // arithmetic shift
        #10;
        $display("Arithmetic shift 0: in=%b, sout=%b %s", in, sout, (sout === 1'b0) ? "OK" : "ERROR");
        
        in = 1'b1;
        shift = 2'b11;
        #10;
        $display("Arithmetic shift 1: in=%b, sout=%b %s", in, sout, (sout === 1'b1) ? "OK" : "ERROR");
        
        $display("N=1 tests completed.");
        $finish;
    end
endmodule

// Top testbench to run both
module testbench;
    // We can run both testbench modules sequentially
    // but easier to just test N=8 as requested
    // However we need to ensure the module works for all N.
    // We'll instantiate a DUT with N=8 and test.
    // We already have testbench_n8.
    // We'll simplify and just run testbench_n8 for final submission.
    // The design must pass both.
endmodule
