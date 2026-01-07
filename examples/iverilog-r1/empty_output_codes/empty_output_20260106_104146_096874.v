// Verilog code that resulted in empty output
// Saved at: 2026-01-06T10:41:46.096904
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

module sync_reg #(
    parameter INIT = 1'b0,
    parameter ASYNC_RESET = 1'b0
) (
    input wire clk,
    input wire rst,
    input wire in,
    output wire out
);

    reg sync_in;
    reg out_reg;
    
    generate
        if (ASYNC_RESET) begin
            // Asynchronous reset
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    sync_in <= INIT;
                end else begin
                    sync_in <= in;
                end
            end
            
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    out_reg <= INIT;
                end else begin
                    out_reg <= sync_in;
                end
            end
        end else begin
            // Synchronous reset
            always @(posedge clk) begin
                if (rst) begin
                    sync_in <= INIT;
                end else begin
                    sync_in <= in;
                end
            end
            
            always @(posedge clk) begin
                if (rst) begin
                    out_reg <= INIT;
                end else begin
                    out_reg <= sync_in;
                end
            end
        end
    endgenerate
    
    assign out = out_reg;
    
endmodule

// Simple testbench
module testbench;
    reg clk;
    reg rst;
    reg in;
    wire out;
    
    sync_reg #(.INIT(1'b0), .ASYNC_RESET(1'b0)) dut (
        .clk(clk),
        .rst(rst),
        .in(in),
        .out(out)
    );
    
    initial begin
        clk = 0;
        rst = 0;
        in = 0;
        
        // Generate a few clocks
        #10 clk = 1;
        #10 clk = 0;
        #10 clk = 1;
        #10 clk = 0;
        
        $finish;
    end
endmodule
