// Verilog code that resulted in empty output
// Saved at: 2026-01-14T12:28:12.355964
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

module YUV422_to_444 (
    input wire [15:0] iYCbCr,
    output reg [7:0] oY,
    output reg [7:0] oCb,
    output reg [7:0] oCr,
    input wire [9:0] iX,
    input wire iCLK,
    input wire iRST_N
);

reg [7:0] cb_reg;
reg [7:0] cr_reg;

always @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N) begin
        cb_reg <= 8'h00;
        cr_reg <= 8'h00;
        oY <= 8'h00;
        oCb <= 8'h00;
        oCr <= 8'h00;
    end else begin
        case (iX[0])
            1'b0: begin // Y and Cb present
                oY <= iYCbCr[15:8];
                oCb <= iYCbCr[7:0];
                oCr <= cr_reg;
                cb_reg <= iYCbCr[7:0];
            end
            1'b1: begin // Y and Cr present
                oY <= iYCbCr[15:8];
                oCr <= iYCbCr[7:0];
                oCb <= cb_reg;
                cr_reg <= iYCbCr[7:0];
            end
        endcase
    end
end

endmodule

module testbench;
    reg [15:0] iYCbCr;
    reg [9:0] iX;
    reg iCLK;
    reg iRST_N;
    wire [7:0] oY;
    wire [7:0] oCb;
    wire [7:0] oCr;
    
    YUV422_to_444 dut (
        .iYCbCr(iYCbCr),
        .oY(oY),
        .oCb(oCb),
        .oCr(oCr),
        .iX(iX),
        .iCLK(iCLK),
        .iRST_N(iRST_N)
    );
    
    initial begin
        iCLK = 0;
        iRST_N = 0;
        iYCbCr = 0;
        iX = 0;
        #10;
        iRST_N = 1;
        #10;
        
        // Test sequence: pixel0 (Cb present), pixel1 (Cr present)
        // Pixel0: Y0 = 0x12, Cb0 = 0x34
        // Pixel1: Y1 = 0x56, Cr0 = 0x78
        // Expected: pixel0 output: Y=0x12, Cb=0x34, Cr=0 (wrong)
        //           pixel1 output: Y=0x56, Cb=0x34, Cr=0x78 (correct)
        
        // Cycle0: Cb present (iX LSB=0)
        iYCbCr = {8'h12, 8'h34};
        iX = 10'h000; // LSB=0
        @(posedge iCLK);
        #1;
        $display("Cycle0: iYCbCr=%h, iX[0]=%b, oY=%h, oCb=%h, oCr=%h", iYCbCr, iX[0], oY, oCb, oCr);
        
        // Cycle1: Cr present (iX LSB=1)
        iYCbCr = {8'h56, 8'h78};
        iX = 10'h001; // LSB=1
        @(posedge iCLK);
        #1;
        $display("Cycle1: iYCbCr=%h, iX[0]=%b, oY=%h, oCb=%h, oCr=%h", iYCbCr, iX[0], oY, oCb, oCr);
        
        // Additional cycles: continue with pairs
        // Pair2: even pixel Cb present at cycle2
        iX = 10'h000;
        iYCbCr = {8'h9A, 8'hBC};
        @(posedge iCLK);
        #1;
        $display("Cycle2: iYCbCr=%h, iX[0]=%b, oY=%h, oCb=%h, oCr=%h", iYCbCr, iX[0], oY, oCb, oCr);
        // Pair2 odd pixel Cr present at cycle3
        iX = 10'h001;
        iYCbCr = {8'hDE, 8'hF0};
        @(posedge iCLK);
        #1;
        $display("Cycle3: iYCbCr=%h, iX[0]=%b, oY=%h, oCb=%h, oCr=%h", iYCbCr, iX[0], oY, oCb, oCr);
        
        #20;
        $finish;
    end
endmodule
