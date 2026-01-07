// Verilog code that resulted in empty output
// Saved at: 2026-01-06T12:39:12.458874
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

module data_cal (
    input clk,
    input rst,
    input [15:0] d,
    input [1:0] sel,
    output reg [4:0] out,
    output reg validout
);

reg [15:0] d_reg;

always @(posedge clk) begin
    if (!rst) begin
        d_reg <= 16'b0;
    end else if (sel == 2'b00) begin
        d_reg <= d;
    end
end

always @(*) begin
    case (sel)
        2'b00: begin
            out = 5'b0;
            validout = 1'b0;
        end
        2'b01: begin
            out = {1'b0, d_reg[3:0]} + {1'b0, d_reg[7:4]};
            validout = 1'b1;
        end
        2'b10: begin
            out = {1'b0, d_reg[3:0]} + {1'b0, d_reg[11:8]};
            validout = 1'b1;
        end
        2'b11: begin
            out = {1'b0, d_reg[3:0]} + {1'b0, d_reg[15:12]};
            validout = 1'b1;
        end
        default: begin
            out = 5'b0;
            validout = 1'b0;
        end
    endcase
end

endmodule

module testbench;
    reg clk = 0;
    reg rst = 0;
    reg [15:0] d;
    reg [1:0] sel;
    wire [4:0] out;
    wire validout;
    
    data_cal dut (clk, rst, d, sel, out, validout);
    
    initial begin
        // Release reset after one clock
        #10;
        rst = 1;
        
        // Test sel=0
        sel = 0;
        d = 16'hA5A5;
        #1;
        if (out !== 0 || validout !== 0) begin
            $display("FAIL sel=0");
            $finish;
        end
        // Wait for clock edge to update d_reg
        @(posedge clk);
        // Now sel=1
        sel = 1;
        #1;
        // d_reg should now be A5A5
        // lower4 = 5, next4 = 10, sum = 15
        if (out !== 15 || validout !== 1) begin
            $display("FAIL sel=1: out=%d", out);
            $finish;
        end
        $display("PASS");
        $finish;
    end
endmodule
