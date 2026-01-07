// Verilog code that resulted in empty output
// Saved at: 2026-01-06T13:10:53.188776
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

module traffic_light (
    input wire clk,
    input wire rst,
    input wire pass,
    output reg R,
    output reg G,
    output reg Y
);

// State definitions
localparam [2:0] S_GREEN_LONG = 3'b001,
                 S_OFF        = 3'b010,
                 S_GREEN_S    = 3'b011,
                 S_OFF2       = 3'b100,
                 S_YELLOW     = 3'b101,
                 S_RED        = 3'b110;

// Counter width: need to count up to 1152 (RED duration)
reg [10:0] counter;

// Next state
reg [2:0] state, next_state;

// Duration constants
localparam D_GREEN_LONG = 1024;
localparam D_OFF        = 128;
localparam D_GREEN_S    = 128;
localparam D_OFF2       = 128;
localparam D_YELLOW     = 512;
localparam D_RED        = 1152; // total cycle 3072

// Output mapping
always @(*) begin
    case (state)
        S_GREEN_LONG: {R, G, Y} = 3'b010;
        S_OFF:        {R, G, Y} = 3'b000;
        S_GREEN_S:    {R, G, Y} = 3'b010;
        S_OFF2:       {R, G, Y} = 3'b000;
        S_YELLOW:     {R, G, Y} = 3'b001;
        S_RED:        {R, G, Y} = 3'b100;
        default:      {R, G, Y} = 3'b000;
    endcase
end

// Sequential logic
always @(posedge clk) begin
    if (rst) begin
        state <= S_GREEN_LONG;
        counter <= 0;
    end else begin
        state <= next_state;
        // counter logic
        if (pass) begin
            if (state != S_GREEN_LONG && state != S_GREEN_S) begin
                counter <= 0;
            end
        end else begin
            if (counter == D_GREEN_LONG-1) begin
                counter <= 0;
            end else if (counter == D_OFF-1) begin
                counter <= 0;
            end else if (counter == D_GREEN_S-1) begin
                counter <= 0;
            end else if (counter == D_OFF2-1) begin
                counter <= 0;
            end else if (counter == D_YELLOW-1) begin
                counter <= 0;
            end else if (counter == D_RED-1) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
            end
        end
    end
end

// Next state logic
always @(*) begin
    next_state = state; // default stay in current state
    if (pass) begin
        if (state != S_GREEN_LONG && state != S_GREEN_S) begin
            next_state = S_GREEN_LONG;
        end
    end else begin
        // Normal state transitions
        case (state)
            S_GREEN_LONG: begin
                if (counter == D_GREEN_LONG-1)
                    next_state = S_OFF;
            end
            S_OFF: begin
                if (counter == D_OFF-1)
                    next_state = S_GREEN_S;
            end
            S_GREEN_S: begin
                if (counter == D_GREEN_S-1)
                    next_state = S_OFF2;
            end
            S_OFF2: begin
                if (counter == D_OFF2-1)
                    next_state = S_YELLOW;
            end
            S_YELLOW: begin
                if (counter == D_YELLOW-1)
                    next_state = S_RED;
            end
            S_RED: begin
                if (counter == D_RED-1)
                    next_state = S_GREEN_LONG;
            end
            default: next_state = S_GREEN_LONG;
        endcase
    end
end

endmodule

// Testbench
module testbench;
reg clk;
reg rst;
reg pass;
wire R, G, Y;

traffic_light dut (clk, rst, pass, R, G, Y);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    // Initialize
    rst = 1;
    pass = 0;
    #20;
    rst = 0;
    // Wait a few cycles
    #100;
    // Test pass signal during off state
    pass = 1;
    #100;
    pass = 0;
    // Run for a few cycles
    #1000;
    // End
    $finish;
end

endmodule
