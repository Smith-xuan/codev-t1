// Verilog code that resulted in empty output
// Saved at: 2026-01-14T09:12:55.341069
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

module DataMemory #(
    parameter ADDR_WIDTH = 12,
    parameter MEM_DEPTH = 2**ADDR_WIDTH
) (
    input clock,
    input [31:0] address,
    input flag,
    input [31:0] data,
    output [31:0] DataOut
);

// Address index: use lower ADDR_WIDTH bits of address
wire [ADDR_WIDTH-1:0] addr_index = address[ADDR_WIDTH-1:0];

// Memory array
reg [31:0] mem [0:MEM_DEPTH-1];

// Combinational read
assign DataOut = mem[addr_index];

// Synchronous write
always @(posedge clock) begin
    if (flag) begin
        mem[addr_index] <= data;
    end
end

endmodule

module testbench;
    reg clock;
    reg [31:0] address;
    reg flag;
    reg [31:0] data;
    wire [31:0] DataOut;
    
    DataMemory dut (.*);
    
    initial begin
        clock = 0;
        address = 0;
        flag = 0;
        data = 0;
        #10 clock = 1; #10 clock = 0;
        
        // Write to address 0
        address = 0;
        data = 32'h12345678;
        flag = 1;
        @(posedge clock);
        #1 flag = 0;
        #5;
        $display("DataOut after write: %h", DataOut);
        
        // Read address 0
        #10;
        $display("DataOut read: %h", DataOut);
        
        $finish;
    end
endmodule
