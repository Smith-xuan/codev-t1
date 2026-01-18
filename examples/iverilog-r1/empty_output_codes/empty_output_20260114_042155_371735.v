// Verilog code that resulted in empty output
// Saved at: 2026-01-14T04:21:55.371769
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

// Register File Module
module registerFile (
    input [4:0] read1,
    input [4:0] read2,
    input [4:0] writeReg,
    input [31:0] writeData,
    input regWrite,
    input clk,
    input startin,
    input [4:0] regNo,
    output [31:0] data1,
    output [31:0] data2,
    output [31:0] val
);

    // Register file storage: 31 registers (1 to 31), register 0 is hardwired zero.
    reg [31:0] registers [1:31];

    // Write logic: synchronous write on rising edge of clk
    always @(posedge clk) begin
        if (!startin && regWrite && (writeReg != 5'b0)) begin
            registers[writeReg] <= writeData;
        end
    end

    // Read logic: combinational reads with zero register special case
    // Also force outputs to zero when startin is high
    wire [31:0] data1_raw, data2_raw, val_raw;

    assign data1_raw = (read1 == 5'b0) ? 32'b0 : registers[read1];
    assign data2_raw = (read2 == 5'b0) ? 32'b0 : registers[read2];
    assign val_raw = (regNo == 5'b0) ? 32'b0 : registers[regNo];

    assign data1 = startin ? 32'b0 : data1_raw;
    assign data2 = startin ? 32'b0 : data2_raw;
    assign val = startin ? 32'b0 : val_raw;

endmodule

// Testbench
module testbench;
    reg [4:0] read1, read2, writeReg, regNo;
    reg [31:0] writeData;
    reg regWrite, clk, startin;
    wire [31:0] data1, data2, val;

    registerFile dut (
        .read1(read1),
        .read2(read2),
        .writeReg(writeReg),
        .writeData(writeData),
        .regWrite(regWrite),
        .clk(clk),
        .startin(startin),
        .regNo(regNo),
        .data1(data1),
        .data2(data2),
        .val(val)
    );

    initial begin
        // Initialize signals
        clk = 0;
        startin = 0;
        regWrite = 0;
        writeReg = 0;
        writeData = 0;
        read1 = 0;
        read2 = 0;
        regNo = 0;

        // Apply start signal to reset
        startin = 1;
        #10;
        clk = 1; #5; clk = 0; #5; // clock pulse
        startin = 0;
        // After start, outputs should be zero, but registers should be unchanged (except maybe register 0)
        // Let's check that data1, data2, val are zero when reading address 0
        read1 = 0; read2 = 0; regNo = 0;
        #10;
        if (data1 !== 32'b0 || data2 !== 32'b0 || val !== 32'b0) begin
            $display("ERROR: Outputs not zero after start signal");
            $finish;
        end
        
        // Write to register 5
        @(posedge clk);
        writeReg = 5;
        writeData = 32'hDEADBEEF;
        regWrite = 1;
        @(negedge clk);
        regWrite = 0;
        // Read register 5 after write
        read1 = 5; read2 = 0; regNo = 5;
        #10;
        if (data1 !== 32'hDEADBEEF) begin
            $display("ERROR: data1 mismatch, got %h, expected DEADBEEF", data1);
            $finish;
        end
        if (val !== 32'hDEADBEEF) begin
            $display("ERROR: val mismatch, got %h, expected DEADBEEF", val);
            $finish;
        end
        // Ensure register 0 reads zero
        read1 = 0;
        #10;
        if (data1 !== 32'b0) begin
            $display("ERROR: register 0 not zero");
            $finish;
        end
        
        // Test simultaneous read and write: write to register 7 while reading register 7
        // Before clock edge, read should see old value (zero because we haven't written yet)
        read1 = 7; writeReg = 7; writeData = 32'h12345678;
        @(posedge clk);
        regWrite = 1;
        #1; // small delay after posedge, still old value
        if (data1 !== 32'b0) begin
            $display("ERROR: read during write cycle should see old value, got %h", data1);
            $finish;
        end
        // After posedge, the write occurs, but our model updates registers at posedge, so after a small delay,
        // the registers array should be updated. However, due to non-blocking assignment, update occurs after the clock edge.
        // In simulation, we can check after a small delay.
        #10;
        if (data1 !== 32'h12345678) begin
            $display("ERROR: after clock edge, read should see new value, got %h", data1);
            $finish;
        end
        
        // Test startin overrides: assert startin, write should be ignored, outputs forced to zero
        startin = 1;
        @(posedge clk);
        writeReg = 9;
        writeData = 32'hAAAAAAAA;
        regWrite = 1;
        @(negedge clk);
        regWrite = 0;
        // After clock, register 9 should still be old value (zero)
        read1 = 9;
        #10;
        if (data1 !== 32'b0) begin
            $display("ERROR: write during startin should be ignored, register 9 not zero");
            $finish;
        end
        // Also outputs forced to zero
        if (data1 !== 32'b0) begin
            $display("ERROR: data1 not zero during startin");
            $finish;
        end
        
        // Test startin with read address zero: outputs zero
        startin = 1;
        read1 = 5; // read some non-zero register (still zero)
        #10;
        if (data1 !== 32'b0) begin
            $display("ERROR: during startin, outputs should be zero regardless of address");
            $finish;
        end
        
        // Test that write to register 0 is ignored
        startin = 0;
        @(posedge clk);
        writeReg = 0;
        writeData = 32'hFFFFFFFF;
        regWrite = 1;
        @(negedge clk);
        regWrite = 0;
        // Read register 0 and ensure it's zero
        read1 = 0;
        #10;
        if (data1 !== 32'b0) begin
            $display("ERROR: write to register 0 should be ignored, but register 0 is not zero");
            $finish;
        end
        
        // Test concurrent read of two different registers
        writeReg = 10; writeData = 32'h11111111;
        regWrite = 1;
        @(posedge clk);
        @(negedge clk);
        regWrite = 0;
        read1 = 10; read2 = 5; // register 5 is zero
        #10;
        if (data1 !== 32'h11111111) begin
            $display("ERROR: read1 mismatch, got %h", data1);
            $finish;
        end
        if (data2 !== 32'b0) begin
            $display("ERROR: read2 mismatch, got %h", data2);
            $finish;
        end
        
        // Test write with startin high (should not update)
        startin = 1;
        @(posedge clk);
        writeReg = 12;
        writeData = 32'h22222222;
        regWrite = 1;
        @(negedge clk);
        regWrite = 0;
        startin = 0;
        // Read register 12, should be unchanged (zero)
        read1 = 12;
        #10;
        if (data1 !== 32'b0) begin
            $display("ERROR: write during startin affected register");
            $finish;
        end
        
        $display("All tests passed!");
        $finish;
    end
endmodule
