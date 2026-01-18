// Verilog code that resulted in empty output
// Saved at: 2026-01-13T21:33:53.787238
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

module piso #(
  parameter PARALLEL_WIDTH = 64,
  parameter SERIAL_WIDTH = 16
) (
  input wire CLK,
  input wire RESET,
  input wire LOAD,
  input wire SHIFT,
  input wire [PARALLEL_WIDTH-1:0] DATA_IN,
  output wire [SERIAL_WIDTH-1:0] DATA_OUT
);

  reg [PARALLEL_WIDTH-1:0] data_reg;
  reg [SERIAL_WIDTH-1:0] out_reg;

  wire load_shift_priority = LOAD | SHIFT; // at least one active

  always @(posedge CLK) begin
    if (RESET) begin
      data_reg <= 0;
      out_reg <= 0;
    end else begin
      case ({LOAD, SHIFT})
        2'b10: begin // LOAD only
          data_reg <= DATA_IN;
          out_reg <= DATA_IN[SERIAL_WIDTH-1:0];
        end
        2'b01: begin // SHIFT only
          data_reg <= data_reg >> SERIAL_WIDTH;
          out_reg <= data_reg[SERIAL_WIDTH-1:0];
        end
        // default: if both LOAD and SHIFT, treat as LOAD (priority)
        // note: if both are 1, case 2'b11 is not defined, so we need to handle.
        // We'll handle both active as LOAD priority
        // Actually, we can use if-else chain earlier.
        // Let's restructure using if-else for clarity.
      endcase
    end
  end

endmodule

module testbench;
  reg CLK;
  reg RESET;
  reg LOAD;
  reg SHIFT;
  reg [63:0] DATA_IN;
  wire [15:0] DATA_OUT;

  piso dut (
    .CLK(CLK),
    .RESET(RESET),
    .LOAD(LOAD),
    .SHIFT(SHIFT),
    .DATA_IN(DATA_IN),
    .DATA_OUT(DATA_OUT)
  );

  initial begin
    CLK = 0;
    RESET = 0;
    LOAD = 0;
    SHIFT = 0;
    DATA_IN = 0;

    // Reset
    RESET = 1;
    @(posedge CLK);
    RESET = 0;
    @(posedge CLK);

    // Load data
    DATA_IN = 64'h1234567890ABCDEF;
    LOAD = 1;
    @(posedge CLK);
    LOAD = 0;
    @(posedge CLK);
    // Check output after load
    $display("After load: DATA_OUT = %h", DATA_OUT);

    // Shift 4 times
    repeat (4) begin
      SHIFT = 1;
      @(posedge CLK);
      SHIFT = 0;
      @(posedge CLK);
      $display("After shift: DATA_OUT = %h", DATA_OUT);
    end

    // Another shift (should output zeros)
    SHIFT = 1;
    @(posedge CLK);
    SHIFT = 0;
    @(posedge CLK);
    $display("After extra shift: DATA_OUT = %h", DATA_OUT);

    $finish;
  end

endmodule
