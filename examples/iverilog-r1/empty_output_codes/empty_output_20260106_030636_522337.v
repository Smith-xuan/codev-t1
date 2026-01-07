// Verilog code that resulted in empty output
// Saved at: 2026-01-06T03:06:36.522363
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

module reset (
    input wire clk,
    output wire rst_n
);
    reg [3:0] count = 4'b0;
    
    always @(posedge clk) begin
        if (count != 4'hF) // saturate at 15
            count <= count + 1;
        else
            count <= count; // keep at 15
    end
    
    assign rst_n = &count;  // AND of all bits
    
endmodule

module testbench;
    reg clk;
    wire rst_n;
    
    reset dut (.clk(clk), .rst_n(rst_n));
    
    integer edge_count = 0;
    
    always @(posedge clk) begin
        edge_count <= edge_count + 1;
        $display("Edge %0d: count = %d, rst_n = %b", edge_count, dut.count, rst_n);
        
        // Check that rst_n behaves correctly
        if (edge_count < 15) begin
            if (rst_n !== 1'b0) begin
                $error("FAIL: At edge %0d, rst_n should be 0 (count = %d), but is %b", 
                       edge_count, dut.count, rst_n);
            end
        end else if (edge_count >= 15) begin
            if (rst_n !== 1'b1) begin
                $error("FAIL: At edge %0d, rst_n should be 1 (count = %d), but is %b", 
                       edge_count, dut.count, rst_n);
            end
        end
    end
    
    // Clock generation
    initial begin
        forever #5 clk = ~clk;
    end
    
    // Stop after enough cycles
    initial begin
        #300 $finish;
    end
endmodule
