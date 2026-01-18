// Verilog code that resulted in empty output
// Saved at: 2026-01-14T06:08:07.259405
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

module delay #(
    parameter WIDTH = 1,
    parameter CYCLES = 1
) (
    input wire clk,
    input wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);

    // If CYCLES is 0, directly connect input to output (combinational)
    generate
        if (CYCLES == 0) begin
            assign data_out = data_in;
        end else begin
            // Shift register array with CYCLES elements
            reg [WIDTH-1:0] shift_reg [0:CYCLES-1];
            
            // Shift register logic
            always @(posedge clk) begin
                // Shift from lower index to higher index (reverse order)
                for (integer i = CYCLES-1; i > 0; i = i - 1) begin
                    shift_reg[i] <= shift_reg[i-1];
                end
                shift_reg[0] <= data_in;
            end
            
            // Output is the last register
            assign data_out = shift_reg[CYCLES-1];
        end
    endgenerate

endmodule

module testbench;
    // Parameters
    parameter WIDTH = 8;
    parameter CYCLES = 3;
    
    // Signals
    reg clk;
    reg [WIDTH-1:0] data_in;
    wire [WIDTH-1:0] data_out;
    
    // Instantiate DUT
    delay #(.WIDTH(WIDTH), .CYCLES(CYCLES)) dut (
        .clk(clk),
        .data_in(data_in),
        .data_out(data_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end
    
    // Test stimulus and verification
    integer cycle;
    reg [WIDTH-1:0] expected_data_out;
    reg [WIDTH-1:0] history [0:10]; // store input values in history
    
    initial begin
        // Initialize
        data_in = 0;
        for (integer i = 0; i < 10; i = i + 1) history[i] = 0;
        
        // Wait for first falling edge to avoid race condition
        @(negedge clk);
        
        // Apply test pattern: incrementing values each cycle
        for (cycle = 0; cycle < 20; cycle = cycle + 1) begin
            @(negedge clk); // wait for negedge to set up data before posedge
            data_in = cycle; // use cycle number as input value
            // The expected output after CYCLES cycles is the input from CYCLES cycles ago
            // Since we capture at negedge, the posedge will capture this value at the next edge.
            // The output lags by CYCLES posedges.
            // We compute expected data_out as the input value from CYCLES cycles ago.
            // We'll store the input in history and compare later.
        end
        
        // Wait a bit more
        #100;
        $finish;
    end
    
    // Monitor and compare
    integer error_count;
    initial begin
        error_count = 0;
        // Wait for initial unknowns to pass
        #100; // let initial unknowns settle
        
        // Monitor at each posedge
        forever begin
            @(posedge clk);
            // Now the data_out is updated for the input captured at previous posedge.
            // We need to compare data_out with the input value that was captured CYCLES cycles ago.
            // Keep track of history on each negedge.
        end
    end
    
endmodule
