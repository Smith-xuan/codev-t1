// Verilog code that resulted in empty output
// Saved at: 2026-01-06T01:39:53.914723
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

module ParallelOUT (
    input EN,
    input clk,
    input rst,          // active-low reset
    input [7:0] RegData,
    input [7:0] Address,
    output reg [7:0] DataOUT
);

    // Asynchronous active-low reset, synchronous enable/address logic
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            DataOUT <= 8'b0;
        end else begin
            // On rising edge of clock, if enabled and address matches, transfer
            if (EN && (Address == 8'hFF)) begin
                DataOUT <= RegData;
            end
        end
    end

endmodule

module testbench;
    reg EN;
    reg clk;
    reg rst;
    reg [7:0] RegData;
    reg [7:0] Address;
    wire [7:0] DataOUT;
    
    ParallelOUT dut (
        .EN(EN),
        .clk(clk),
        .rst(rst),
        .RegData(RegData),
        .Address(Address),
        .DataOUT(DataOUT)
    );
    
    initial begin
        clk = 0;
        #5 clk = 1;
        #5 clk = 0;
    end
    
    initial begin
        // Initialize
        EN = 0;
        rst = 0;
        Address = 0;
        RegData = 0;
        #10;
        rst = 1;
        #5;
        EN = 1;
        Address = 8'hFF;
        RegData = 8'h55;
        @(posedge clk);
        #1;
        $display("DataOUT = %h", DataOUT);
        if (DataOUT !== 8'h55) $display("ERROR: Expected 55");
        #5 $finish;
    end
endmodule
