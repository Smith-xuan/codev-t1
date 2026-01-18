// Verilog code that resulted in empty output
// Saved at: 2026-01-15T07:15:09.992386
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

module adc_fir (
  input fir_clk,
  input rst,
  input [15:0] adc_indata,
  output [15:0] adc_outdata
);
  reg [15:0] delay [0:15];
  integer i;
  
  wire [20:0] sum;
  // Compute sum of all delay registers
  assign sum = delay[0] + delay[1] + delay[2] + delay[3] + delay[4] + delay[5] + delay[6] + delay[7] +
               delay[8] + delay[9] + delay[10] + delay[11] + delay[12] + delay[13] + delay[14] + delay[15];
  
  // Shift register
  always @(posedge fir_clk) begin
    if (~rst) begin
      for (i = 0; i < 16; i = i + 1) begin
        delay[i] <= 16'b0;
      end
    end else begin
      // shift right, newest at delay[0]
      delay[0] <= adc_indata;
      delay[1] <= delay[0];
      delay[2] <= delay[1];
      delay[3] <= delay[2];
      delay[4] <= delay[3];
      delay[5] <= delay[4];
      delay[6] <= delay[5];
      delay[7] <= delay[6];
      delay[8] <= delay[7];
      delay[9] <= delay[8];
      delay[10] <= delay[9];
      delay[11] <= delay[10];
      delay[12] <= delay[11];
      delay[13] <= delay[12];
      delay[14] <= delay[13];
      delay[15] <= delay[14];
    end
  end
  
  assign adc_outdata = sum >> 5;
endmodule

module testbench;
  reg clk;
  reg rst;
  reg [15:0] adc_in;
  wire [15:0] adc_out;
  
  adc_fir dut (
    .fir_clk(clk),
    .rst(rst),
    .adc_indata(adc_in),
    .adc_outdata(adc_out)
  );
  
  initial begin
    clk = 0;
    rst = 1; // active low, so deassert reset
    adc_in = 0;
    // Apply reset
    rst = 0;
    #10;
    rst = 1;
    #10;
    
    // Test with constant input 1
    adc_in = 16'h0001;
    #10; // wait one clock cycle
    repeat (35) begin
      #10;
    end
    
    // Test with ramp
    adc_in = 16'h0002;
    #10;
    adc_in = 16'h0003;
    #10;
    adc_in = 16'h0004;
    #10;
    
    $finish;
  end
  
  always #5 clk = ~clk;
endmodule
