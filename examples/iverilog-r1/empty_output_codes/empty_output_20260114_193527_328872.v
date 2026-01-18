// Verilog code that resulted in empty output
// Saved at: 2026-01-14T19:35:27.328910
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

module m2_test;
    reg [7:0] a;
    wire [7:0] m2_out;
    function automatic [7:0] m2;
        input [7:0] in;
        reg [7:0] shifted;
        begin
            shifted = in << 1;
            if (in[7]) shifted = shifted ^ 8'h1b;
            m2 = shifted;
        end
    endfunction
    assign m2_out = m2(a);
    
    initial begin
        $display("Testing m2 with selected bytes:");
        // Test cases from AES S-box multiplication table
        a = 8'h00; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h01; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h02; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h03; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h04; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h05; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h06; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h07; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h08; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h09; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h0a; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h0b; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h0c; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h0d; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h0e; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h0f; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h10; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h11; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h12; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h13; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h14; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h15; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h16; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h17; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h18; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h19; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h1a; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h1b; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h1c; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h1d; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h1e; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h1f; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h20; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h40; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'h80; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        a = 8'hff; #1 $display("a=%0h m2_out=%0h", a, m2_out);
        
        $finish;
    end
endmodule

module testbench;
    // dummy
endmodule
