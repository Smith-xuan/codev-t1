// Verilog code that resulted in empty output
// Saved at: 2026-01-13T22:03:07.624771
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

module audio_clock(
    input CLK_18_4,
    input RST,
    output AUD_BCK,
    output AUD_LRCK,
    output LRCK_2X,
    output LRCK_4X
);

    // Counters
    reg [3:0] bck_cnt;  // 0 to 11 (12 cycles)
    reg [8:0] lrck_cnt; // 0 to 383 (384 cycles)
    
    // Internal clock signals
    reg bck, lrck, lrck_2x, lrck_4x;
    
    always @(posedge CLK_18_4 or negedge RST) begin
        if (!RST) begin
            bck_cnt <= 0;
            lrck_cnt <= 0;
            bck <= 0;
            lrck <= 0;
            lrck_2x <= 0;
            lrck_4x <= 0;
        end else begin
            // BCK counter: counts 0 to 11
            if (bck_cnt == 11)
                bck_cnt <= 0;
            else
                bck_cnt <= bck_cnt + 1;
                
            // LRCK counter: counts 0 to 383
            if (lrck_cnt == 383)
                lrck_cnt <= 0;
            else
                lrck_cnt <= lrck_cnt + 1;
                
            // Generate BCK (50% duty cycle: high when count >= 6)
            bck <= (bck_cnt < 6);
                
            // Generate LRCK (low for left channel: count < 192)
            lrck <= (lrck_cnt < 192);
                
            // Generate LRCK_2X (high for first half of 2X period)
            lrck_2x <= (lrck_cnt < 96);
                
            // Generate LRCK_4X (high for first half of 4X period)
            lrck_4x <= (lrck_cnt < 48);
        end
    end
    
    assign AUD_BCK = bck;
    assign AUD_LRCK = lrck;
    assign LRCK_2X = lrck_2x;
    assign LRCK_4X = lrck_4x;
    
endmodule

// Simple testbench
module testbench;
    reg CLK_18_4;
    reg RST;
    wire AUD_BCK;
    wire AUD_LRCK;
    wire LRCK_2X;
    wire LRCK_4X;
    
    audio_clock dut (
        .CLK_18_4(CLK_18_4),
        .RST(RST),
        .AUD_BCK(AUD_BCK),
        .AUD_LRCK(AUD_LRCK),
        .LRCK_2X(LRCK_2X),
        .LRCK_4X(LRCK_4X)
    );
    
    // Clock generation: 18.432 MHz half period = 27.126 ns
    initial begin
        CLK_18_4 = 0;
        forever #27.126 CLK_18_4 = ~CLK_18_4;
    end
    
    initial begin
        RST = 0;
        #200;
        RST = 1;
        #1000000;
        $finish;
    end
    
endmodule
