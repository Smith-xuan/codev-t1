// Verilog code that resulted in empty output
// Saved at: 2026-01-14T14:03:55.593080
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

module led_breathe_display (
    input clk,
    input rst_n,
    output [7:0] led_data
);

    // Generate 1 microsecond tick (50 cycles of 50 MHz)
    reg [5:0] us_cnt;  // 0-49 (6 bits)
    wire tick_us;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            us_cnt <= 0;
        else if (us_cnt == 49)
                us_cnt <= 0;
            else
                us_cnt <= us_cnt + 1;
    end
    assign tick_us = (us_cnt == 49);

    // Generate 1 millisecond tick (1000 us)
    reg [9:0] ms_cnt;  // 0-999 (10 bits)
    wire tick_ms;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ms_cnt <= 0;
        else if (tick_us) begin
            if (ms_cnt == 999)
                ms_cnt <= 0;
            else
                ms_cnt <= ms_cnt + 1;
        end
    end
    assign tick_ms = (ms_cnt == 999) & tick_us;  // pulse at end of millisecond

    // Generate 1 second tick
    reg [25:0] s_cnt;  // 0-49,999,999 (26 bits)
    wire tick_s;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            s_cnt <= 0;
        else if (tick_ms) begin
            if (s_cnt == 49_999_999)
                s_cnt <= 0;
            else
                s_cnt <= s_cnt + 1;
        end
    end
    assign tick_s = (s_cnt == 49_999_999) & tick_ms;

    // Sub-counter to update every 2 milliseconds
    reg [1:0] sub_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sub_cnt <= 0;
        else if (tick_ms)
            sub_cnt <= sub_cnt + 1;
    end
    wire update = (sub_cnt[0] == 0); // every 2 ms

    // Breathing LED register
    reg [7:0] brightness;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            brightness <= 0;
        end else if (tick_ms && update) begin
            // Update brightness every 2 milliseconds
            if (ms_cnt < 500) begin
                // First half of second: increase
                if (brightness < 255)
                    brightness <= brightness + 1;
            end else begin
                // Second half of second: decrease
                if (brightness > 0)
                    brightness <= brightness - 1;
            end
        end
    end

    assign led_data = brightness;

endmodule

// Testbench
module testbench;
    reg clk;
    reg rst_n;
    wire [7:0] led_data;

    led_breathe_display dut (
        .clk(clk),
        .rst_n(rst_n),
        .led_data(led_data)
    );

    // 50 MHz clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20 ns period
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        #20000000; // 2 seconds simulation time
        $finish;
    end

    // Monitor changes
    integer last_brightness;
    initial begin
        last_brightness = 0;
        forever begin
            @(posedge clk);
            if (led_data !== last_brightness) begin
                $display("Time = %0t ns, ms_cnt = %0d, brightness = %0d", $time, dut.ms_cnt, led_data);
                last_brightness = led_data;
            end
        end
    end

endmodule
