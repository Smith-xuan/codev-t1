// Verilog code that resulted in empty output
// Saved at: 2026-01-07T04:31:47.292784
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

`timescale 1ns/1ps

module Delay_Counter5 #(
    parameter CYCLES_0_5 = 50_000_000
) (
    input clk,
    input reset_n,
    output reg enable_frame
);
    reg [31:0] counter;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 0;
            enable_frame <= 1'b0;
        end else begin
            if (counter == CYCLES_0_5 - 1) begin
                counter <= 0;
                enable_frame <= 1'b1;
            end else begin
                counter <= counter + 1;
                enable_frame <= 1'b0;
            end
        end
    end
endmodule

module Frame_Counter5 #(
    parameter COUNT_TO = 30
) (
    input clk,
    input reset_n,
    input enable_frame,
    output reg enable_next
);
    reg [5:0] count;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= 0;
            enable_next <= 1'b0;
        end else begin
            if (enable_frame) begin
                if (count == COUNT_TO - 1) begin
                    count <= 0;
                    enable_next <= 1'b1;
                end else begin
                    count <= count + 1;
                    enable_next <= 1'b0;
                end
            end else begin
                enable_next <= 1'b0;
            end
        end
    end
endmodule

module counter_point5sec #(
    parameter CYCLES_0_5 = 50_000_000
) (
    input clk,
    input enable_my_counter,
    output enable_next
);
    wire enable_frame;
    wire reset_n = ~enable_my_counter; // active low reset
    
    Delay_Counter5 #(
        .CYCLES_0_5(CYCLES_0_5)
    ) u_delay_counter (
        .clk(clk),
        .reset_n(reset_n),
        .enable_frame(enable_frame)
    );
    
    Frame_Counter5 #(
        .COUNT_TO(30)
    ) u_frame_counter (
        .clk(clk),
        .reset_n(reset_n),
        .enable_frame(enable_frame),
        .enable_next(enable_next)
    );
endmodule

module testbench;
    reg clk;
    reg enable_my_counter;
    wire enable_next;
    wire enable_frame;
    
    counter_point5sec #(.CYCLES_0_5(5)) dut (clk, enable_my_counter, enable_next);
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    integer frame_cnt = 0;
    integer next_cnt = 0;
    
    initial begin
        enable_my_counter = 0;
        #30;
        enable_my_counter = 1;
        #2000; // enough time for 30 pulses
        enable_my_counter = 0;
        #30;
        $finish;
    end
    
    always @(posedge clk) begin
        #1;
        if (enable_frame && enable_my_counter) begin
            frame_cnt = frame_cnt + 1;
            if (frame_cnt == 30) begin
                $display("INFO: 30th enable_frame pulse at time %0t", $time);
            end
        end
        if (enable_next && enable_my_counter) begin
            next_cnt = next_cnt + 1;
            $display("PASS: enable_next pulse detected at time %0t (frame_cnt=%0d)", $time, frame_cnt);
            if (next_cnt == 1) begin
                if (frame_cnt == 30) begin
                    $display("SUCCESS: enable_next appears after exactly 30 enable_frame pulses");
                end else begin
                    $display("FAIL: enable_next appears after %0d enable_frame pulses", frame_cnt);
                end
            end
        end
    end
    
    initial begin
        #2100;
        if (frame_cnt == 30 && next_cnt == 0) begin
            $display("ERROR: enable_next not triggered after 30 pulses");
        end else if (frame_cnt >= 30 && next_cnt >= 1) begin
            // ok
        end
    end
    
endmodule
