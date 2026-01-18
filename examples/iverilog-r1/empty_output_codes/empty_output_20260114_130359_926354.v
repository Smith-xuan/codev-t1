// Verilog code that resulted in empty output
// Saved at: 2026-01-14T13:03:59.926377
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

module time_manager (
    input setting,
    input min_set,
    input hour_set,
    input clk,
    input rst_n,
    output [3:0] min_set_0,
    output [3:0] min_set_1,
    output [3:0] hour_set_0,
    output [3:0] hour_set_1,
    output [5:0] min_ini,
    output [5:0] hour_ini
);

reg [5:0] minute_reg, hour_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        minute_reg <= 6'd0;
        hour_reg <= 6'd0;
    end else begin
        if (setting) begin
            if (min_set) begin
                if (minute_reg == 6'd59)
                    minute_reg <= 6'd0;
                else
                    minute_reg <= minute_reg + 6'd1;
            end
            if (hour_set) begin
                if (hour_reg == 6'd23)
                    hour_reg <= 6'd0;
                else
                    hour_reg <= hour_reg + 6'd1;
            end
        end
    end
end

assign min_ini = minute_reg;
assign hour_ini = hour_reg;

// Convert minute_reg to tens and ones BCD digits
reg [3:0] min_tens, min_ones;
always @* begin
    min_tens = minute_reg / 10;
    min_ones = minute_reg - min_tens * 10;
end

// Convert hour_reg to tens and ones BCD digits
reg [3:0] hr_tens, hr_ones;
always @* begin
    hr_tens = hour_reg / 10;
    hr_ones = hour_reg - hr_tens * 10;
end

assign min_set_0 = min_ones;
assign min_set_1 = min_tens;
assign hour_set_0 = hr_ones;
assign hour_set_1 = hr_tens;

endmodule

module testbench;
    reg clk;
    reg rst_n;
    reg setting;
    reg min_set;
    reg hour_set;
    wire [3:0] min_set_0, min_set_1;
    wire [3:0] hour_set_0, hour_set_1;
    wire [5:0] min_ini, hour_ini;
    
    time_manager dut (
        .setting(setting),
        .min_set(min_set),
        .hour_set(hour_set),
        .clk(clk),
        .rst_n(rst_n),
        .min_set_0(min_set_0),
        .min_set_1(min_set_1),
        .hour_set_0(hour_set_0),
        .hour_set_1(hour_set_1),
        .min_ini(min_ini),
        .hour_ini(hour_ini)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        // Initialize inputs
        setting = 0;
        min_set = 0;
        hour_set = 0;
        rst_n = 0;
        
        // Apply reset
        #10;
        rst_n = 1;
        #10;
        
        // Check initial values after reset
        if (min_ini !== 6'd0) $display("ERROR: min_ini not 0 after reset, got %d", min_ini);
        if (hour_ini !== 6'd0) $display("ERROR: hour_ini not 0 after reset, got %d", hour_ini);
        if (min_set_0 !== 4'd0) $display("ERROR: min_set_0 not 0, got %d", min_set_0);
        if (min_set_1 !== 4'd0) $display("ERROR: min_set_1 not 0, got %d", min_set_1);
        if (hour_set_0 !== 4'd0) $display("ERROR: hour_set_0 not 0, got %d", hour_set_0);
        if (hour_set_1 !== 4'd0) $display("ERROR: hour_set_1 not 0, got %d", hour_set_1);
        
        // Test minute increment (setting mode active)
        setting = 1;
        min_set = 1;
        #10; // wait one clock cycle
        // Expect minute_reg = 1
        if (min_ini !== 6'd1) $display("ERROR: min_ini not 1 after increment, got %d", min_ini);
        // BCD digits: tens=0, ones=1
        if (min_set_0 !== 4'd1) $display("ERROR: min_set_0 not 1, got %d", min_set_0);
        if (min_set_1 !== 4'd0) $display("ERROR: min_set_1 not 0, got %d", min_set_1);
        
        #10; // another increment
        if (min_ini !== 6'd2) $display("ERROR: min_ini not 2 after second increment, got %d", min_ini);
        if (min_set_0 !== 4'd2) $display("ERROR: min_set_0 not 2, got %d", min_set_0);
        if (min_set_1 !== 4'd0) $display("ERROR: min_set_1 not 0, got %d", min_set_1);
        
        // Test wrap at 59 -> 0
        // Set minute to 58
        rst_n = 0;
        #10;
        rst_n = 1;
        setting = 1;
        min_set = 1;
        #10; // minute = 1, 2, ... need to go to 58. Instead we can directly set register? Not possible.
        // Let's just simulate many cycles; we'll write a loop.
        // But for simplicity, we can skip and test later.
        // Instead we'll test wrap by setting minute to 59 and then increment.
        // Let's use a faster approach: we'll directly manipulate the register via backdoor? Not possible.
        // So we'll simulate 59 increments.
        // Let's write a loop in testbench.
        // We'll stop the previous simulation and start fresh.
        // We'll create a new testbench with more systematic tests.
        $finish;
    end
    
endmodule
