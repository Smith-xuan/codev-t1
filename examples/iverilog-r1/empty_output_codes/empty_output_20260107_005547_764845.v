// Verilog code that resulted in empty output
// Saved at: 2026-01-07T00:55:47.764902
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

module score_module (
    input wire [1:0] action_type,
    input wire clk,
    input wire rst,
    output reg [6:0] score_local,
    output reg [6:0] max_score_local
);

    // Initialize registers (synthesizable for FPGA)
    initial begin
        score_local = 7'b0;
        max_score_local = 7'b0;
    end

    // Combinational next-state logic
    always @* begin
        if (rst) begin
            score_local = 7'b0;
            // max_score_local unchanged
        end else begin
            case (action_type)
                2'b00: begin // miss
                    if (score_local != 7'b0) begin
                        score_local = score_local - 7'd1;
                    end
                end
                2'b01: begin // correct hit
                    score_local = score_local + 7'd1;
                    // If the new score equals the current maximum, increment max (per spec)
                    if ((score_local - 7'd1) + 7'd1 == max_score_local) begin
                        max_score_local = max_score_local + 7'd1;
                    end
                end
                default: ; // unchanged
            endcase
        end
    end

endmodule

// Minimal testbench
module testbench;
    reg [1:0] action_type;
    reg clk;
    reg rst;
    wire [6:0] score_local;
    wire [6:0] max_score_local;
    
    score_module dut (action_type, clk, rst, score_local, max_score_local);
    
    // Clock
    initial begin
        clk = 0;
        #300 $finish;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst = 1;
        action_type = 0;
        @(posedge clk);
        rst = 0;
        
        // Simple check
        if (score_local !== 0) $display("ERROR: score not 0");
        if (max_score_local !== 0) $display("ERROR: max not 0");
        
        // Hit once
        action_type = 2'b01;
        @(posedge clk);
        if (score_local !== 1) $display("ERROR: score not 1");
        if (max_score_local !== 0) $display("ERROR: max changed");
        
        // Hit second time
        @(posedge clk);
        if (score_local !== 2) $display("ERROR: score not 2");
        
        // Miss
        action_type = 2'b00;
        @(posedge clk);
        if (score_local !== 1) $display("ERROR: score not 1 after miss");
        
        $display("Test done");
    end
endmodule
