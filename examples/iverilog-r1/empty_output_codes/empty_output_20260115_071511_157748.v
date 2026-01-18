// Verilog code that resulted in empty output
// Saved at: 2026-01-15T07:15:11.157778
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

// Audio clock generator
module audio_clock (
    input CLK_18_4,
    input RST,
    output AUD_BCK,
    output AUD_LRCK
);

    reg [8:0] ref_counter; // 0 to 383

    always @(posedge CLK_18_4 or negedge RST) begin
        if (!RST) begin
            ref_counter <= 0;
        end else begin
            if (ref_counter == 383) begin
                ref_counter <= 0;
            end else begin
                ref_counter <= ref_counter + 1;
            end
        end
    end

    // Bit clock: period 12 ref cycles, 50% duty cycle (high for cycles 6-11)
    assign AUD_BCK = (ref_counter[2:0] >= 3'd6) ? 1'b1 : 1'b0;

    // Left/right clock: period 384 ref cycles, high for cycles 192-383
    assign AUD_LRCK = (ref_counter >= 96'd192) ? 1'b1 : 1'b0;

endmodule

// Testbench
module testbench;
    reg CLK_18_4;
    reg RST;
    wire AUD_BCK;
    wire AUD_LRCK;

    audio_clock dut (
        .CLK_18_4(CLK_18_4),
        .RST(RST),
        .AUD_BCK(AUD_BCK),
        .AUD_LRCK(AUD_LRCK)
    );

    // Generate 18.432 MHz clock (period 54.25 ns)
    // For simulation, we'll use a faster clock to see cycles.
    // Let's use 10 ns period (100 MHz) for easier simulation.
    // But we need to ensure division ratios are correct.
    // Let's use a 10 ns period for simulation.
    // Actually we can keep 18.432 MHz but simulation may be long.
    // Let's use a faster clock for simulation but keep the same ratio.
    // We'll use a clock period of 10 ns (100 MHz) just for simulation.
    // The division ratios are independent of absolute frequency.
    initial begin
        CLK_18_4 = 0;
        forever #5 CLK_18_4 = ~CLK_18_4; // 10 ns period (100 MHz)
    end

    initial begin
        RST = 0; // active low, start with reset
        // Wait a few cycles
        #20;
        RST = 1; // release reset
        #10000; // simulate some time
        $finish;
    end

    // Monitor signals
    integer ref_count = 0;
    integer bck_posedge_count = 0;
    integer lr_posedge_count = 0;
    integer last_bck = 0;
    integer last_lr = 0;
    real bck_period_sum = 0;
    real lr_period_sum = 0;
    
    always @(posedge CLK_18_4) begin
        ref_count <= ref_count + 1;
    end

    always @(posedge AUD_BCK) begin
        if (last_bck == 0) begin
            bck_posedge_count <= bck_posedge_count + 1;
            // measure period
            // we need previous posedge time
            // We'll just count.
        end
        last_bck <= 1;
    end

    always @(negedge AUD_BCK) begin
        last_bck <= 0;
    end

    always @(posedge AUD_LRCK) begin
        if (last_lr == 0) begin
            lr_posedge_count <= lr_posedge_count + 1;
        end
        last_lr <= 1;
    end

    always @(negedge AUD_LRCK) begin
        last_lr <= 0;
    end

    initial begin
        #100000;
        $display("Reset count: %0d", ref_count);
        $display("BCK posedge count: %0d", bck_posedge_count);
        $display("LRCK posedge count: %0d", lr_posedge_count);
        // Calculate frequencies
        // BCK period in clock cycles: each BCK period has 12 ref cycles.
        // We can compute BCK frequency = ref_freq / 12 = 100 MHz / 12 = 8.333 MHz not correct.
        // Actually we need to compute based on our design.
        // Let's compute based on counts.
        // Each BCK period spans 12 ref cycles.
        // If we counted N BCK posedges, they should correspond to 12*N ref cycles.
        // But we counted ref_count.
        // Let's compute expected BCK period.
        $display("Simulation ended.");
        $finish;
    end
endmodule
