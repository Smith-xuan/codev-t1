// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:54:13.802459
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

module FIR(
    output [17:0] Dout,
    input [7:0] Din,
    input clk,
    input reset
);
    // Coefficients
    localparam [5:0] b0 = 6'd7;
    localparam [5:0] b1 = 6'd17;
    localparam [5:0] b2 = 6'd32;
    localparam [5:0] b3 = 6'd46;
    localparam [5:0] b4 = 6'd52;
    localparam [5:0] b5 = 6'd46;
    localparam [5:0] b6 = 6'd32;
    localparam [5:0] b7 = 6'd17;
    localparam [5:0] b8 = 6'd7;
    
    // Shift register for past 8 inputs: x[0] holds x[n-1] (newest), x[7] holds x[n-8] (oldest)
    reg [7:0] x [0:7];
    integer i;
    
    // Registered output
    reg [17:0] dout_reg;
    
    assign Dout = dout_reg;
    
    always @(posedge clk) begin
        if (reset) begin
            // Clear shift registers
            for (i = 0; i < 8; i = i + 1) begin
                x[i] <= 8'd0;
            end
            // Output is b0 * Din (since all registers are zero)
            dout_reg <= b0 * Din;
        end else begin
            // Compute output using current Din and the shift register values
            // (which contain the past inputs from the previous cycle)
            dout_reg <= b0*Din + b1*x[0] + b2*x[1] + b3*x[2] + b4*x[3] + 
                        b5*x[4] + b6*x[5] + b7*x[6] + b8*x[7];
            // Update shift registers: shift in the current input
            x[0] <= Din;
            for (i = 0; i < 7; i = i + 1) begin
                x[i+1] <= x[i];
            end
        end
    end
    
endmodule

module testbench;
    reg clk, reset;
    reg [7:0] Din;
    wire [17:0] Dout;
    
    FIR dut (.Dout(Dout), .Din(Din), .clk(clk), .reset(reset));
    
    // Reference model: keep track of last 8 inputs
    reg [7:0] ref_history [0:7];
    integer j;
    
    task update_ref(input [7:0] sample);
        // Shift older samples
        for (j = 0; j < 7; j = j + 1) begin
            ref_history[j] <= ref_history[j+1];
        end
        // Insert new sample as oldest? Wait need to map correctly.
        // At each clock edge, we capture the input Din and store it as x[n].
        // The filter uses x[n-1]..x[n-8] to compute output.
        // So we need to store the current input in a queue that holds the last 8 inputs.
        // Let's store newest at index 0, oldest at index 7.
        ref_history[0] <= sample;
        // Actually we need to shift: newest = sample, previous newest becomes second newest.
        // Simulate:
        // For i=0 to 6: ref_history[i] <= ref_history[i+1];
        // Then ref_history[7] <= sample; because sample is newest (x[n]), which should be x[n-1] for next cycle? Wait.
        // Let's think: At time n, before clock edge, ref_history holds x[n-1]..x[n-8] with x[n-1] at index 0.
        // At clock edge, we sample x[n] (input). After shift, ref_history should hold x[n]..x[n-7] (since we lose x[n-8]).
        // So we need: ref_history[0] = sample (x[n]), ref_history[1] = old ref_history[0] (x[n-1]), ...
        // That's exactly: for i=0 to 6: ref_history[i] <= ref_history[i+1]; then ref_history[7] <= sample;
        // But that moves sample to ref_history[7] which would be oldest, not newest.
        // Let's adopt a simple approach: we'll compute expected output using a queue that stores the last 8 inputs, and compute expected output using the same formula as the filter.
        // We'll store the input values in an array, where arr[0] is the newest, arr[7] is oldest.
        // On each clock edge, we shift in the new input: arr[0] = new input, others shift.
        // Then expected output is b0*new_input + b1*arr[0] + b2*arr[1] + ... + b8*arr[7]
        // But note: at the clock edge, the input is already the new input, and the stored array is the one before shift.
        // So we need to compute using the old array.
        // Let's implement: before the clock edge, we have old array. After the edge, we update array.
        // We'll write a separate task to compute expected output given the old array and new input.
    endtask
    
    // We'll do a simpler test: apply sequence 1,2,3,4,5,6,7,8,9,10 with reset at start.
    // We'll compute expected outputs manually using a script, but we can compute inside testbench using a loop.
    // We'll store the input history in an array and compute expected using real multiplication.
    // Let's implement:
    reg [7:0] test_input_hist [0:9];
    integer k;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        reset = 1;
        Din = 0;
        for (k = 0; k <= 9; k = k + 1) test_input_hist[k] = 0;
        
        // Initialize filter
        @(posedge clk);
        #1;
        reset = 0;
        
        // Apply test sequence 1 to 10
        for (k = 1; k <= 10; k = k + 1) begin
            Din = k;
            @(posedge clk);
            #1;
            // Update expected input history for next cycle
            // We'll simulate the filter's behavior: store previous Din as newest.
            // Actually we need to compute expected output using the filter's own delay line.
            // Let's maintain a queue that shifts each cycle.
        end
        
        $finish;
    end
    
    // Let's compute expected output using a simple model: keep an array of last 8 inputs.
    // We'll update this array on each clock edge (same as filter).
    reg [7:0] expected_history [0:7];
    integer idx2;
    
    always @(posedge clk) begin
        if (reset) begin
            for (idx2 = 0; idx2 < 8; idx2 = idx2 + 1) expected_history[idx2] <= 0;
        end else begin
            // Compute expected output before updating history? The filter computes output using old history before update.
            // We need to capture the current Din and compute product using current expected_history (which is old before update).
            // But since we are in always block at posedge, the expected_history values are the same as filter's register values.
            // We can compute expected output now, but we need to compare Dout after the clock edge.
            // Let's compute expected output using the current expected_history and current Din.
            // However note that the filter updates its registers after computing the output (since we compute dout_reg in the same always block but after the register assignment).
            // Actually in the filter, dout_reg is assigned using the register values before they are updated (because the non-blocking assignments for registers happen after the always block). So we can compute expected output similarly.
            // We'll compute expected output as a separate register and compare.
        end
    end
    
    // Instead, let's write a simple test that checks the condition at reset.
    initial begin
        // Wait for initial reset deassertion
        @(posedge clk);
        #1;
        // Now registers are zero, Din is 0 (but we set Din to 5 earlier). Actually we set Din to k in loop.
        // Let's just run a simple test.
        // We'll do a new simulation with a single input 5 and check output.
    end
endmodule
