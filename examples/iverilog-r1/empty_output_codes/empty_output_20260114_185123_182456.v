// Verilog code that resulted in empty output
// Saved at: 2026-01-14T18:51:23.182482
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

module ClockDivider2K (
    input cin,
    output cout
);

    reg [14:0] counter;
    reg cout_reg;

    always @(posedge cin) begin
        if (counter == 15'd12500) begin  // using old counter value 12500
            cout_reg <= ~cout_reg;
        end
        if (counter == 15'd24999) begin
            counter <= 15'd0;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    assign cout = cout_reg;

    initial begin
        counter = 0;
        cout_reg = 0;
    end

endmodule

module testbench;
    reg cin;
    wire cout;
    
    ClockDivider2K dut ( .cin(cin), .cout(cout) );
    
    // Clock generation
    initial begin
        cin = 0;
        forever #5 cin = ~cin; // 10 time units period
    end
    
    // Monitoring
    integer cycle_count = 0;
    reg prev_cout;
    integer toggle_count = 0;
    
    always @(posedge cin) begin
        cycle_count <= cycle_count + 1;
    end
    
    initial prev_cout = 0;
    always @(cout) begin
        #1;
        if (prev_cout !== cout) begin
            toggle_count <= toggle_count + 1;
            $display("Toggle #%0d at time %0t, cycle %0d, counter=%0d", toggle_count, $time, cycle_count, dut.counter);
            prev_cout <= cout;
        end
    end
    
    initial begin
        #10000;
        $finish;
    end
endmodule
