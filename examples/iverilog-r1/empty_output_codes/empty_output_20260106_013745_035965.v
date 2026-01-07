// Verilog code that resulted in empty output
// Saved at: 2026-01-06T01:37:45.035998
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

module CNT1SEC (
    input CLK,
    input RST,
    output EN1HZ
);

    // Counter maximum value: count from 0 to 49,999,999 inclusive
    // That's 50 million cycles for 50 MHz clock => 1 second
    localparam MAX_COUNT = 49_999_999;
    localparam CNT_WIDTH = $clog2(MAX_COUNT + 1); // 26

    reg [CNT_WIDTH-1:0] cnt;

    // Counter logic
    always @(posedge CLK) begin
        if (RST || (cnt == MAX_COUNT)) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
        end
    end

    // Enable output (combinational)
    assign EN1HZ = (cnt == MAX_COUNT);

endmodule

// Testbench with reduced count for simulation
module testbench;
    reg CLK;
    reg RST;
    wire EN1HZ;

    // For simulation, use a small count to verify behavior
    // Let's define a parameter to override MAX_COUNT
    // We can re-define localparam but need to modify module definition.
    // Instead, we can use a generate block or simply create a separate module for test.
    // Let's create a wrapper that uses a smaller MAX_COUNT.
    // We'll create a parameterized version for testing.

    // Actually, we can just instantiate CNT1SEC with a modified localparam using `define.
    // Let's do that.

    // Define simulation parameter
    `define SIM_MAX_COUNT 9  // Small number for quick simulation

    // But we cannot redefine localparam inside module; we need to modify CNT1SEC definition.
    // Let's create a separate module CNT1SEC_SIM that uses a parameter.
    // However, for simplicity, we'll keep CNT1SEC as is and use a generate ifdef.
    // Let's create a wrapper module that inherits from CNT1SEC.

    // We'll just instantiate CNT1SEC as normal, but for simulation we can override parameters via defparam.
    // However, localparam cannot be overridden by defparam.
    // So we need to change CNT1SEC to use a parameter.
    // Let's do that: make MAX_COUNT a parameter with default value.
    // But requirement says module named CNT1SEC with given interface.
    // We can add a parameter but keep default as 49_999_999.

    // Let's redesign: add parameter MAX_COUNT with default 49_999_999.
    // That's acceptable; many designs have parameters.

    // So I'll modify CNT1SEC to have a parameter.

    // But the user didn't ask for parameter; but we can still include it.
    // I'll produce a parameterized version, but ensure the default is correct.

    // Let's rewrite CNT1SEC with parameter.
    // Then testbench can instantiate with small value.

    // However, the user might expect a non-parameterized module.
    // But we can include parameter inside module but not in port list.
    // That's fine.

    // Let's create final code with parameter.
    // Then testbench will use parameter.

endmodule
