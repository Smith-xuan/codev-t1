// Verilog code that resulted in empty output
// Saved at: 2026-01-14T06:39:49.899291
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

module ClockDivider #(parameter D = 1) (
    input cin,
    output cout
);
    reg [31:0] counter;
    reg out_reg;
    
    always @(posedge cin) begin
        if (counter == D-1) begin
            counter <= 0;
            out_reg <= ~out_reg;
        end else begin
            counter <= counter + 1;
        end
    end
    
    assign cout = out_reg;
endmodule

module testbench;
    reg cin;
    wire cout1, cout2;
    
    ClockDivider #(.D(1)) u1 (.cin(cin), .cout(cout1));
    ClockDivider #(.D(2)) u2 (.cin(cin), .cout(cout2));
    
    initial begin
        cin = 0;
        #5;
        forever #5 cin = ~cin;
    end
    
    integer last_edge1_time, last_edge2_time;
    integer count1, count2;
    real freq1, freq2;
    
    initial begin
        // Wait for initial conditions
        #100;
        
        // Measure cout1 rising edges
        last_edge1_time = 0;
        count1 = 0;
        forever begin
            @(posedge cout1);
            count1 = count1 + 1;
            if (count1 == 1) begin
                last_edge1_time = $time;
            end else begin
                freq1 = 1000.0 / ($time - last_edge1_time);
                $display("cout1 rising edge at time %0d, period since last = %0d, freq = %f Hz", $time, $time - last_edge1_time, freq1);
                last_edge1_time = $time;
            end
            if (count1 >= 5) $stop;
        end
    end
    
    initial begin
        #200;
        $finish;
    end
endmodule
