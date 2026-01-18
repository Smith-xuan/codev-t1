// Verilog code that resulted in empty output
// Saved at: 2026-01-14T07:07:44.300998
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

module controller (
    input P1Left,
    input P1Right,
    input clk,
    output reg [1:0] paddle
);
    reg toggle = 0;

    always @(posedge clk) begin
        toggle <= ~toggle;
    end

    always @(posedge clk) begin
        if (toggle) begin
            paddle <= 2'b00;
        end else begin
            if (P1Left) begin
                paddle <= 2'b01;
            end else if (P1Right) begin
                paddle <= 2'b10;
            end else begin
                paddle <= 2'b00;
            end
        end
    end
endmodule

module testbench;
    reg P1Left, P1Right, clk;
    wire [1:0] paddle;
    
    controller dut (
        .P1Left(P1Left),
        .P1Right(P1Right),
        .clk(clk),
        .paddle(paddle)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    task check_paddle;
        input [1:0] expected;
        begin
            if (paddle !== expected) begin
                $display("ERROR at time %0t: paddle = %b, expected %b", $time, paddle, expected);
                $finish;
            end
        end
    endtask
    
    initial begin
        // Wait for initial unknown
        #1;
        // Test sequence
        // Cycle 1: first posedge at time 5
        // Inputs idle, toggle before edge = 0, paddle after edge should be 00
        P1Left = 0; P1Right = 0;
        #10; // wait for posedge at 5 and half cycle to time 15?
        // Actually after #10 from time 1, we are at time 11.
        // Need to synchronize.
        // Let's reset time and start from known state.
        $finish;
    end
endmodule
