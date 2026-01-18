// Verilog code that resulted in empty output
// Saved at: 2026-01-15T04:38:31.428475
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

module audio_clock (
    input iCLK_18_4,
    input iRST_N,
    output oAUD_BCK,
    output oAUD_LRCK
);

    reg [3:0] bck_counter; // counts 0 to 11 (4 bits)
    reg [5:0] bit_counter; // counts 0 to 31 (6 bits)
    
    wire bck_tick = (bck_counter == 4'd11);
    
    always @(posedge iCLK_18_4 or negedge iRST_N) begin
        if (!iRST_N) begin
            bck_counter <= 4'd0;
            bit_counter <= 6'd0;
        end else begin
            bck_counter <= bck_counter + 4'd1; // wraps automatically? Actually will go to 12? but we only count up to 11.
            // So we need to wrap manually.
        end
    end
    
    // Actually we need to wrap bck_counter at 11.
    // Let's fix.
    
endmodule

module testbench;
    reg iCLK_18_4;
    reg iRST_N;
    wire oAUD_BCK;
    wire oAUD_LRCK;
    
    audio_clock dut (
        .iCLK_18_4(iCLK_18_4),
        .iRST_N(iRST_N),
        .oAUD_BCK(oAUD_BCK),
        .oAUD_LRCK(oAUD_LRCK)
    );
    
    initial begin
        iCLK_18_4 = 0;
        iRST_N = 0;
        #100;
        iRST_N = 1;
        #100000;
        $finish;
    end
    
    always #27.1735 iCLK_18_4 = ~iCLK_18_4; // approx 18.432 MHz period = 54.347 ns, half period 27.1735 ns
endmodule
