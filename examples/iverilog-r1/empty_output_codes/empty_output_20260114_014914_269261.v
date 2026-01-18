// Verilog code that resulted in empty output
// Saved at: 2026-01-14T01:49:14.269295
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

module DigitalCalendar (
    input clk,
    input reset,
    output [6:0] year,
    output [4:0] month,
    output [4:0] day
);

reg [6:0] year_reg;
reg [4:0] month_reg;
reg [4:0] day_reg;

assign year = year_reg;
assign month = month_reg;
assign day = day_reg;

wire [4:0] max_day;
assign max_day = (month_reg == 5'd1) ? 5'd31 :
                 (month_reg == 5'd2) ? 5'd28 :
                 (month_reg == 5'd4 || month_reg == 5'd6 || month_reg == 5'd9 || month_reg == 5'd11) ? 5'd30 : 5'd31;

always @(posedge clk) begin
    if (reset) begin
        year_reg <= 7'd1;
        month_reg <= 5'd1;
        day_reg <= 5'd1;
    end else begin
        if (day_reg == max_day) begin
            day_reg <= 5'd1;
            if (month_reg == 5'd12) begin
                month_reg <= 5'd1;
                year_reg <= year_reg + 1'b1;
            end else begin
                month_reg <= month_reg + 1'b1;
            end
        end else begin
            day_reg <= day_reg + 1'b1;
        end
    end
end

endmodule

module testbench;
    reg clk;
    reg reset;
    wire [6:0] year;
    wire [4:0] month;
    wire [4:0] day;
    
    DigitalCalendar dut (
        .clk(clk),
        .reset(reset),
        .year(year),
        .month(month),
        .day(day)
    );
    
    // Generate clock: period 20, 50% duty
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // Reference model
    integer ref_year, ref_month, ref_day;
    
    // Helper function to compute max day for reference
    function integer ref_max_day;
        input integer month;
        begin
            if (month == 1) ref_max_day = 31;
            else if (month == 2) ref_max_day = 28;
            else if (month == 4 || month == 6 || month == 9 || month == 11) ref_max_day = 30;
            else ref_max_day = 31;
        end
    endfunction
    
    // Monitor process
    initial begin
        // Initialize
        reset = 1;
        ref_year = 1;
        ref_month = 1;
        ref_day = 1;
        #20; // wait for one clock cycle with reset high
        reset = 0;
        
        // Wait for a few cycles
        #1000; // run for some cycles
        $finish;
    end
    
    // Compare reference and DUT at each posedge clk
    always @(posedge clk) begin
        // Update reference model for next cycle (same as DUT does)
        if (reset) begin
            // Reference model also reset (though not physically present)
            ref_year = 1;
            ref_month = 1;
            ref_day = 1;
        end else begin
            if (ref_day == ref_max_day(ref_month)) begin
                ref_day = 1;
                if (ref_month == 12) begin
                    ref_month = 1;
                    ref_year = ref_year + 1;
                end else begin
                    ref_month = ref_month + 1;
                end
            end else begin
                ref_day = ref_day + 1;
            end
        end
        
        // Compare DUT outputs with reference (registered outputs)
        // Note: DUT outputs are registered, so they update after posedge.
        // We need to wait a small time after posedge to sample stable values.
        #1;
        if (year !== ref_year || month !== ref_month || day !== ref_day) begin
            $display("ERROR at time %0t: Mismatch! DUT: year=%0d month=%0d day=%0d, REF: year=%0d month=%0d day=%0d",
                     $time, year, month, day, ref_year, ref_month, ref_day);
            $finish;
        end
    end
    
endmodule
