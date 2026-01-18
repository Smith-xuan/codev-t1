// Verilog code that resulted in empty output
// Saved at: 2026-01-14T12:50:28.241744
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

module generadorpmw (
  input CLKOUT2,
  input [7:0] dutty,
  output PMW
);

reg [11:0] counter = 0;
wire [11:0] sum = dutty + 12'd180;  // 8'b10110100 = 180

always @(posedge CLKOUT2) begin
  if (counter == 12'd3600) begin
    counter <= 12'd0;
  end else begin
    counter <= counter + 1'b1;
  end
end

assign PMW = (counter < sum);

endmodule

module testbench;
  reg CLKOUT2;
  reg [7:0] dutty;
  wire PMW;
  
  generadorpmw dut (.CLKOUT2(CLKOUT2), .dutty(dutty), .PMW(PMW));
  
  // Clock generation: period of 10 ns
  initial begin
    CLKOUT2 = 0;
    forever #5 CLKOUT2 = ~CLKOUT2; // 10 ns period
  end
  
  initial begin
    // Test case 1: dutty = 0
    dutty = 8'd0;
    #2000; // wait for enough cycles
    
    // Test case 2: dutty = 255
    dutty = 8'd255;
    #2000;
    
    // Test case 3: dutty = 128
    dutty = 8'd128;
    #2000;
    
    // Test case 4: dutty = 100
    dutty = 8'd100;
    #2000;
    
    $finish;
  end
  
  // Verification tasks
  integer cycle_count = 0;
  integer last_counter = 0;
  
  always @(posedge CLKOUT2) begin
    cycle_count <= cycle_count + 1;
    last_counter <= dut.counter;
  end
  
  // Check counter reset at 3600
  always @(posedge CLKOUT2) begin
    if (dut.counter == 12'd3600) begin
      $display("Counter reached 3600 at cycle %0d, time %0t", cycle_count, $time);
      // On next clock edge, counter should be 0
      #10; // wait for next posedge
      if (dut.counter == 12'd0) begin
        $display("Counter reset to 0 correctly.");
      end else begin
        $display("ERROR: Counter did NOT reset to 0.");
      end
    end
  end
  
  // Check PMW behavior for dutty = 0
  initial begin
    wait (cycle_count > 200);
    if (dutty == 8'd0) begin
      // Check that PMW is high while counter < 180
      // We can sample at certain times.
      #1; // small delay after posedge
      if (dut.counter < 180) begin
        if (PMW !== 1'b1) begin
          $display("ERROR: PMW should be high when counter < 180.");
        end
      end else begin
        if (PMW !== 1'b0) begin
          $display("ERROR: PMW should be low when counter >= 180.");
        end
      end
    end
  end
  
endmodule
