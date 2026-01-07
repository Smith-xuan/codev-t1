// Verilog code that resulted in empty output
// Saved at: 2026-01-05T23:19:36.044655
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

module RegFile4x8 (
    input clock,
    input clear,
    input [1:0] read_index1,
    input [1:0] read_index2,
    input write,
    input [1:0] write_index,
    input [7:0] write_data,
    output reg [7:0] read_data1,
    output reg [7:0] read_data2
);

    // 4 registers each 8 bits
    reg [7:0] registers [0:3];
    
    integer i;
    
    // Asynchronous clear and synchronous write on negative edge
    always @(negedge clock or posedge clear) begin
        if (clear) begin
            // Clear all registers to zero
            for (i = 0; i < 4; i = i + 1) begin
                registers[i] <= 8'b0;
            end
        end else if (write) begin
            // Write to selected register on negative edge of clock
            registers[write_index] <= write_data;
        end
    end
    
    // Combinational read ports
    always @(*) begin
        read_data1 = registers[read_index1];
        read_data2 = registers[read_index2];
    end

endmodule

module testbench;
    // empty
endmodule
