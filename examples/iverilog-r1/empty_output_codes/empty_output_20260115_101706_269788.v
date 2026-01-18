// Verilog code that resulted in empty output
// Saved at: 2026-01-15T10:17:06.269812
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

`timescale 1ns/1ns

module crc32 (
    input new_bit,
    input data_in,
    output [31:0] data_out
);
    parameter POLY = 32'h04C11DB7;
    reg [31:0] crc = 32'hFFFFFFFF;
    
    always @(posedge new_bit) begin
        crc <= (crc << 1) ^ ((crc[31]) ? POLY : 32'b0) ^ {31'b0, data_in};
    end
    
    assign data_out = crc;
endmodule

module testbench;
    reg new_bit;
    reg data_in;
    wire [31:0] data_out;
    
    // Generate 1MHz clock for new_bit
    initial begin
        new_bit = 0;
        forever #500 new_bit = ~new_bit; // period 1000 ns
    end
    
    crc32 dut (.new_bit(new_bit), .data_in(data_in), .data_out(data_out));
    
    // Test string "123456789"
    reg [7:0] str [0:8];
    integer i, j;
    
    initial begin
        // Initialize string bytes
        str[0] = "1"; // 0x31
        str[1] = "2"; // 0x32
        str[2] = "3"; // 0x33
        str[3] = "4"; // 0x34
        str[4] = "5"; // 0x35
        str[5] = "6"; // 0x36
        str[6] = "7"; // 0x37
        str[7] = "8"; // 0x38
        str[8] = "9"; // 0x39
        
        // Wait a few cycles for stability
        #2000;
        
        // Process each byte, MSB first
        for (i = 0; i < 9; i = i + 1) begin
            for (j = 7; j >= 0; j = j - 1) begin
                // Set data_in before the rising edge
                // Wait for falling edge to set data_in (setup time)
                @(negedge new_bit);
                data_in = str[i][j];
                // Wait for next rising edge to capture data_in
                // The DUT updates on posedge, so we can just wait for posedge
                // and then change data_in for next bit.
                // Actually we need to keep data_in stable around posedge.
                // Let's wait for posedge, then after a small delay set data_in for next bit.
                // But for this test, we can just set data_in after posedge.
            end
        end
        
        // Wait a few cycles after last bit
        #1000;
        
        $display("CRC32 result: %h", data_out);
        $display("Expected CRC32 (without final XOR): %h", 32'hCBF43926);
        if (data_out === 32'hCBF43926)
            $display("Test PASSED");
        else
            $display("Test FAILED");
        $finish;
    end
    
    // Stop simulation after some time
    initial begin
        #50000 $finish;
    end
endmodule
