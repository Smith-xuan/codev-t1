// Verilog code that resulted in empty output
// Saved at: 2026-01-13T21:00:37.380873
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

module ram_en_switch (
    input [31:0] addr,
    input bram_en,
    output [24:0] bram_en_out,
    input [799:0] bram_data_in,
    output [31:0] bram_data_out
);

    // Extract the upper 8 bits of address
    wire [7:0] segment_index_raw = addr[19:12];

    // Generate one-hot enable for the segment if index is within 0-24
    reg [24:0] segment_onehot;
    always @(*) begin
        segment_onehot = 25'b0;
        if (segment_index_raw <= 24) begin
            segment_onehot[segment_index_raw] = 1'b1;
        end
    end

    // BRAM enable output: each bit enabled only if bram_en is high and corresponding segment is selected
    assign bram_en_out = bram_en ? segment_onehot : 25'b0;

    // BRAM data output: select the appropriate 32-bit segment from bram_data_in
    // segment index must be <=24, else default to 0
    reg [31:0] segment_data;
    always @(*) begin
        if (segment_index_raw <= 24) begin
            segment_data = bram_data_in[(segment_index_raw * 32) +: 32];
        end else begin
            segment_data = 32'b0;
        end
    end
    assign bram_data_out = segment_data;

endmodule


// Testbench
module testbench;
    reg [31:0] addr;
    reg bram_en;
    wire [24:0] bram_en_out;
    reg [799:0] bram_data_in;
    wire [31:0] bram_data_out;

    ram_en_switch dut (
        .addr(addr),
        .bram_en(bram_en),
        .bram_en_out(bram_en_out),
        .bram_data_in(bram_data_in),
        .bram_data_out(bram_data_out)
    );

    // Initialize memory data: each segment gets a distinct value
    // We'll fill segment i with value (i + 1) * 32 (for testing)
    integer i;
    initial begin
        bram_data_in = 0;
        for (i = 0; i < 25; i = i + 1) begin
            bram_data_in[(i * 32) +: 32] = (i + 1) * 32;
        end

        // Test suite
        // 1. bram_en = 0 -> all enables off regardless of address
        bram_en = 0;
        addr = 32'h0;
        @(0);
        $display("Test 1: bram_en=0, any address");
        $display("  bram_en_out = %b", bram_en_out);
        if (bram_en_out !== 25'b0) begin
            $error("FAIL: bram_en_out should be zero when bram_en low");
        end

        // 2. bram_en = 1, select segment 0
        bram_en = 1;
        // Set addr[19:12] = 0
        addr = (0 << 12);
        @(0);
        $display("Test 2: segment 0");
        $display("  bram_en_out = %b", bram_en_out);
        if (bram_en_out !== (25'b1 << 0)) begin
            $error("FAIL: bram_en_out not one-hot for segment 0");
        end
        if (bram_data_out !== (0 + 1) * 32) begin
            $error("FAIL: data mismatch segment 0");
        end

        // 3. segment 5
        addr = (5 << 12);
        @(0);
        $display("Test 3: segment 5");
        $display("  bram_en_out = %b", bram_en_out);
        if (bram_en_out !== (25'b1 << 5)) begin
            $error("FAIL: bram_en_out not one-hot for segment 5");
        end
        if (bram_data_out !== (5 + 1) * 32) begin
            $error("FAIL: data mismatch segment 5");
        end

        // 4. segment 24 (last valid)
        addr = (24 << 12);
        @(0);
        $display("Test 4: segment 24");
        $display("  bram_en_out = %b", bram_en_out);
        if (bram_en_out !== (25'b1 << 24)) begin
            $error("FAIL: bram_en_out not one-hot for segment 24");
        end
        if (bram_data_out !== (24 + 1) * 32) begin
            $error("FAIL: data mismatch segment 24");
        end

        // 5. out-of-range index 25
        addr = (25 << 12);
        @(0);
        $display("Test 5: out-of-range index 25");
        $display("  bram_en_out = %b", bram_en_out);
        if (bram_en_out !== 25'b0) begin
            $error("FAIL: bram_en_out not zero for out-of-range");
        end
        if (bram_data_out !== 32'b0) begin
            $error("FAIL: data not zero for out-of-range");
        end

        // 6. large index 255
        addr = (255 << 12);
        @(0);
        $display("Test 6: out-of-range index 255");
        $display("  bram_en_out = %b", bram_en_out);
        if (bram_en_out !== 25'b0) begin
            $error("FAIL: bram_en_out not zero for large index");
        end
        if (bram_data_out !== 32'b0) begin
            $error("FAIL: data not zero for large index");
        end

        // 7. random address where only bits 19:12 matter, other bits arbitrary
        // Test that bits other than 19:12 don't affect segment selection
        // Use segment index 10
        bram_en = 1;
        // Create an address where bits 19:12 = 10, but also set some other bits to non-zero.
        // Let's set addr = {12'hfff, 8'h10, 12'hfff} to see if that changes index.
        // Actually we need to set bits 19:12 specifically.
        // Let's construct: addr[31:0] = {12'hfff, 8'h10, 12'hfff}.
        // That means bits 31:20 are all 1, bits 19:12 are 0x10 (16 decimal?), wait 0x10 is 16 decimal not 10.
        // We'll set bits 19:12 = 10 (binary 0001010). So use 8'h0A.
        addr = {12'hFFF, 8'h0A, 12'hFFF};
        @(0);
        $display("Test 7: random address with bits 19:12=10, other bits non-zero");
        $display("  bram_en_out = %b", bram_en_out);
        if (bram_en_out !== (25'b1 << 10)) begin
            $error("FAIL: bram_en_out incorrect for random address");
        end
        if (bram_data_out !== (10 + 1) * 32) begin
            $error("FAIL: data mismatch for random address");
        end

        // 8. Loop through all valid indices 0..24 and verify enable and data
        $display("Test 8: exhaustive loop over segment indices 0..24");
        bram_en = 1;
        for (i = 0; i < 25; i = i + 1) begin
            // Set addr[19:12] = i
            addr = (i << 12);
            @(0);
            // Check enable: only bit i should be high
            if (bram_en_out !== (25'b1 << i)) begin
                $error("FAIL: segment %0d enable not one-hot", i);
            end
            // Check data
            if (bram_data_out !== ((i + 1) * 32)) begin
                $error("FAIL: segment %0d data mismatch, got %h expected %h", i, bram_data_out, ((i + 1) * 32));
            end
            if (i % 5 == 0) $display("  segment %0d OK", i);
        end

        $display("All tests passed");
        $finish;
    end

endmodule
