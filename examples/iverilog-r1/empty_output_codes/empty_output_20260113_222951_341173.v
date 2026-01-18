// Verilog code that resulted in empty output
// Saved at: 2026-01-13T22:29:51.341207
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

module chooseCMD (
    input isData,
    input [15:0] SPI_data,
    input [7:0] N,
    output reg [15:0] CMD1,
    output reg [15:0] CMD2,
    output reg [15:0] Eth_I_max,
    output reg [15:0] Eth_I_min,
    output reg [15:0] Eth_Temp_max,
    output reg [15:0] Eth_I_work,
    output reg [15:0] Eth_kor,
    output reg [15:0] Eth_Imp_time,
    output reg [15:0] Eth_Start,
    output reg [15:0] Eth_Full_stop,
    output reg [15:0] Eth_Calibr,
    output reg [15:0] Eth_Ch_num
);

// No reset, registers start unknown

always @(posedge isData) begin
    case (N)
        8'd0: CMD1 <= SPI_data;
        8'd1: CMD2 <= SPI_data;
        8'd2: Eth_I_max <= SPI_data;
        8'd3: Eth_I_min <= SPI_data;
        8'd4: Eth_Temp_max <= SPI_data;
        8'd5: Eth_I_work <= SPI_data;
        8'd6: Eth_kor <= SPI_data;
        8'd7: Eth_Imp_time <= SPI_data;
        8'd8: Eth_Start <= SPI_data;
        8'd9: Eth_Full_stop <= SPI_data;
        8'd10: Eth_Calibr <= SPI_data;
        8'd11: Eth_Ch_num <= SPI_data;
        default: ; // ignore other N values, retain previous values
    endcase
end

endmodule

// Testbench
module testbench;
    reg isData;
    reg [15:0] SPI_data;
    reg [7:0] N;
    
    wire [15:0] CMD1;
    wire [15:0] CMD2;
    wire [15:0] Eth_I_max;
    wire [15:0] Eth_I_min;
    wire [15:0] Eth_Temp_max;
    wire [15:0] Eth_I_work;
    wire [15:0] Eth_kor;
    wire [15:0] Eth_Imp_time;
    wire [15:0] Eth_Start;
    wire [15:0] Eth_Full_stop;
    wire [15:0] Eth_Calibr;
    wire [15:0] Eth_Ch_num;
    
    chooseCMD dut (
        .isData(isData),
        .SPI_data(SPI_data),
        .N(N),
        .CMD1(CMD1),
        .CMD2(CMD2),
        .Eth_I_max(Eth_I_max),
        .Eth_I_min(Eth_I_min),
        .Eth_Temp_max(Eth_Temp_max),
        .Eth_I_work(Eth_I_work),
        .Eth_kor(Eth_kor),
        .Eth_Imp_time(Eth_Imp_time),
        .Eth_Start(Eth_Start),
        .Eth_Full_stop(Eth_Full_stop),
        .Eth_Calibr(Eth_Calibr),
        .Eth_Ch_num(Eth_Ch_num)
    );
    
    // Clock generation (isData) - but it's a data signal, not necessarily periodic.
    // We'll simulate rising edges at appropriate times.
    
    initial begin
        isData = 0;
        SPI_data = 0;
        N = 0;
        
        // Wait a bit
        #10;
        
        // Test writing to CMD1 (N=0)
        N = 0;
        SPI_data = 16'h1234;
        #5;
        @(posedge isData); // rising edge
        #1; // wait a bit after edge
        if (CMD1 !== 16'h1234) begin
            $display("ERROR: CMD1 didn't update correctly. Expected 1234, got %h", CMD1);
            $finish;
        end
        
        // Write to CMD2 (N=1)
        N = 1;
        SPI_data = 16'h5678;
        #5;
        @(posedge isData);
        #1;
        if (CMD2 !== 16'h5678) begin
            $display("ERROR: CMD2 didn't update correctly. Expected 5678, got %h", CMD2);
            $finish;
        end
        
        // Write to Eth_I_max (N=2)
        N = 2;
        SPI_data = 16'h9ABC;
        #5;
        @(posedge isData);
        #1;
        if (Eth_I_max !== 16'h9ABC) begin
            $display("ERROR: Eth_I_max didn't update correctly. Expected 9ABC, got %h", Eth_I_max);
            $finish;
        end
        
        // Write to Eth_I_min (N=3)
        N = 3;
        SPI_data = 16'hDEF0;
        #5;
        @(posedge isData);
        #1;
        if (Eth_I_min !== 16'hDEF0) begin
            $display("ERROR: Eth_I_min didn't update correctly. Expected DEF0, got %h", Eth_I_min);
            $finish;
        end
        
        // Write to Eth_Temp_max (N=4)
        N = 4;
        SPI_data = 16'h1111;
        #5;
        @(posedge isData);
        #1;
        if (Eth_Temp_max !== 16'h1111) begin
            $display("ERROR: Eth_Temp_max didn't update correctly. Expected 1111, got %h", Eth_Temp_max);
            $finish;
        end
        
        // Write to Eth_I_work (N=5)
        N = 5;
        SPI_data = 16'h2222;
        #5;
        @(posedge isData);
        #1;
        if (Eth_I_work !== 16'h2222) begin
            $display("ERROR: Eth_I_work didn't update correctly. Expected 2222, got %h", Eth_I_work);
            $finish;
        end
        
        // Write to Eth_kor (N=6)
        N = 6;
        SPI_data = 16'h3333;
        #5;
        @(posedge isData);
        #1;
        if (Eth_kor !== 16'h3333) begin
            $display("ERROR: Eth_kor didn't update correctly. Expected 3333, got %h", Eth_kor);
            $finish;
        end
        
        // Write to Eth_Imp_time (N=7)
        N = 7;
        SPI_data = 16'h4444;
        #5;
        @(posedge isData);
        #1;
        if (Eth_Imp_time !== 16'h4444) begin
            $display("ERROR: Eth_Imp_time didn't update correctly. Expected 4444, got %h", Eth_Imp_time);
            $finish;
        end
        
        // Write to Eth_Start (N=8)
        N = 8;
        SPI_data = 16'h5555;
        #5;
        @(posedge isData);
        #1;
        if (Eth_Start !== 16'h5555) begin
            $display("ERROR: Eth_Start didn't update correctly. Expected 5555, got %h", Eth_Start);
            $finish;
        end
        
        // Write to Eth_Full_stop (N=9)
        N = 9;
        SPI_data = 16'h6666;
        #5;
        @(posedge isData);
        #1;
        if (Eth_Full_stop !== 16'h6666) begin
            $display("ERROR: Eth_Full_stop didn't update correctly. Expected 6666, got %h", Eth_Full_stop);
            $finish;
        end
        
        // Write to Eth_Calibr (N=10)
        N = 10;
        SPI_data = 16'h7777;
        #5;
        @(posedge isData);
        #1;
        if (Eth_Calibr !== 16'h7777) begin
            $display("ERROR: Eth_Calibr didn't update correctly. Expected 7777, got %h", Eth_Calibr);
            $finish;
        end
        
        // Write to Eth_Ch_num (N=11)
        N = 11;
        SPI_data = 16'h8888;
        #5;
        @(posedge isData);
        #1;
        if (Eth_Ch_num !== 16'h8888) begin
            $display("ERROR: Eth_Ch_num didn't update correctly. Expected 8888, got %h", Eth_Ch_num);
            $finish;
        end
        
        // Test that N=12 (invalid) does not affect registers
        N = 12;
        SPI_data = 16'hFFFF;
        #5;
        @(posedge isData);
        #1;
        if (CMD1 === 16'hFFFF) begin
            $display("ERROR: CMD1 incorrectly updated by invalid N=12");
            $finish;
        end
        
        // Test that N=0 (already written) retains previous value
        N = 0;
        SPI_data = 16'hAAAA; // new value
        #5;
        @(posedge isData);
        #1;
        if (CMD1 !== 16'hAAAA) begin
            $display("ERROR: CMD1 didn't update to new value AAAAAA");
            $finish;
        end
        
        // All tests passed
        $display("All tests passed!");
        $finish;
    end
endmodule
