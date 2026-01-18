// Verilog code that resulted in empty output
// Saved at: 2026-01-14T16:05:47.365094
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

module pwm_gen (
    input CLKOUT3,
    input [7:0] grado,
    output PMW3
);
    reg [11:0] counter = 0;
    wire [11:0] compare;
    
    assign compare = {4'b0, grado} + 12'd45;
    
    always @(posedge CLKOUT3) begin
        if (counter == 1800) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end
    
    assign PMW3 = (counter < compare);
endmodule

module testbench;
    reg CLKOUT3;
    reg [7:0] grado;
    wire PMW3;
    
    pwm_gen dut (.CLKOUT3(CLKOUT3), .grado(grado), .PMW3(PMW3));
    
    initial begin
        CLKOUT3 = 0;
        forever #5 CLKOUT3 = ~CLKOUT3;
    end
    
    // Checker
    reg [11:0] expected_compare;
    always @(posedge CLKOUT3) begin
        expected_compare = {4'b0, grado} + 12'd45;
        if (PMW3 !== (dut.counter < expected_compare)) begin
            $display("ERROR at time %0t: counter=%0d, grado=%0d, PWM=%0d, expected=%0d",
                     $time, dut.counter, grado, PMW3, (dut.counter < expected_compare));
        end
    end
    
    initial begin
        #100;
        grado = 0;
        repeat (3600) @(posedge CLKOUT3);
        grado = 100;
        repeat (3600) @(posedge CLKOUT3);
        grado = 255;
        repeat (3600) @(posedge CLKOUT3);
        $finish;
    end
endmodule
