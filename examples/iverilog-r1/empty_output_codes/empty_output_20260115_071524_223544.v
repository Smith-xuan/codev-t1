// Verilog code that resulted in empty output
// Saved at: 2026-01-15T07:15:24.223572
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

module mv_avg_filter_8_v1_0 (
    input clk,
    input rst,
    input [31:0] i32_prescaler,
    input [13:0] is14_data,
    output [13:0] os14_data
);

    reg [31:0] prescaler_counter;
    reg [13:0] samples [0:7];
    reg [16:0] sum;  // 17-bit signed sum
    
    wire sample_enable;
    
    // Prescaler counter logic
    assign sample_enable = (prescaler_counter == 32'd0);
    
    always @(posedge clk) begin
        if (rst) begin
            prescaler_counter <= 32'd0;
            sum <= 17'd0;
            // Clear samples
            for (integer i = 0; i < 8; i = i + 1) begin
                samples[i] <= 14'd0;
            end
        end else begin
            if (sample_enable) begin
                // Reload prescaler counter
                prescaler_counter <= i32_prescaler;
                // Sample new data
                // Shift samples: new sample enters index 0, shift right
                for (integer i = 7; i > 0; i = i - 1) begin
                    samples[i] <= samples[i-1];
                end
                samples[0] <= is14_data;
                // Update running sum: subtract oldest sample, add new sample
                // Oldest sample is samples[7] before shift (since we shift right)
                // Need to get the value before shift
                // Instead, capture oldest before modifying samples array?
                // Let's compute sum differently: sum = sum - samples[7] + is14_data;
                // But samples[7] is the old value (before shift)
                // However, we have already updated the samples array in the same always block;
                // The order within the same block is sequential, but we need to use the OLD values.
                // We can store the old oldest in a temporary variable.
            end else begin
                prescaler_counter <= prescaler_counter - 32'd1;
            end
        end
    end
    
    // Update sum when sample_enable is high
    always @(posedge clk) begin
        if (rst) begin
            sum <= 17'd0;
        end else if (sample_enable) begin
            // sum <= sum - $signed(samples[7]) + $signed(is14_data);
            // Need to sign extend samples[7] to 17 bits
            sum <= sum - {{3{samples[7][13]}}, samples[7]} + {{3{is14_data[13]}}, is14_data};
        end
    end
    
    // Output assignment: take upper 14 bits of sum (bits 16 downto 3)
    assign os14_data = sum[16:3];
    
endmodule

module testbench;
    reg clk;
    reg rst;
    reg [31:0] i32_prescaler;
    reg [13:0] is14_data;
    wire [13:0] os14_data;
    
    mv_avg_filter_8_v1_0 dut (
        .clk(clk),
        .rst(rst),
        .i32_prescaler(i32_prescaler),
        .is14_data(is14_data),
        .os14_data(os14_data)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst = 1;
        i32_prescaler = 32'd1; // sample every clock
        is14_data = 14'd0;
        #10;
        rst = 0;
        
        // Test sequence: feed values 1,2,3,4,5,6,7,8 then continue
        is14_data = 14'd1;
        #10;
        is14_data = 14'd2;
        #10;
        is14_data = 14'd3;
        #10;
        is14_data = 14'd4;
        #10;
        is14_data = 14'd5;
        #10;
        is14_data = 14'd6;
        #10;
        is14_data = 14'd7;
        #10;
        is14_data = 14'd8;
        #10;
        
        // After 8 samples, sum = 36 (1+2+...+8 = 36), average = 36/8 = 4.5 truncated? 
        // Expect output? Since we take bits 16:3, let's compute.
        // sum = 36 decimal, binary unsigned: 100100 (6 bits). In 17-bit signed, positive, bits 16:0 = 0...0100100.
        // Bits 16:3 correspond to bits 16 down to 3, which are zeros except bit 5? Let's compute.
        // But our sum is 36, which is less than 2^5=32. So bit5 = 1 (since 32). Bits 16:3 includes bit5 as 1, others zero.
        // That's 0b100000 (32) in 14 bits? Actually bits 16:3 selects 14 bits, but only bit5 is 1, i.e., value 32.
        // However expected average is 4.5, integer division truncates toward zero? actually floor.
        // With shift right arithmetic by 3 bits, 36 >>> 3 = 4 (since 36/8 = 4.5, floor = 4).
        // Let's compute: 36 in binary: 100100. Arithmetic shift right 3: sign bit 0, so result bits: 100100 >> 3 = 1001 (9?) Wait: 36 decimal = 0b00000000000100100 (17 bits). Shift right 3: becomes 0b00000000000001001 (bits 16:3? Let's compute later.
        // Let's simulate and see.
        
        // Continue feeding values
        #100;
        $finish;
    end
    
endmodule
