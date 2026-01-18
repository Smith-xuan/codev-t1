// Verilog code that resulted in empty output
// Saved at: 2026-01-15T00:22:53.290885
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

module STSystem_SR (
    input txclk,
    input ld,
    input st,
    input opn,
    input sp,
    input [7:0] d,
    output TX,
    output [10:0] extra_loaddata
);

reg [10:0] shift_reg;

always @(posedge txclk or negedge ld) begin
    if (!ld) begin
        shift_reg <= {st, d, opn, sp};
    end else begin
        shift_reg <= {shift_reg[9:0], 1'b1};
    end
end

assign TX = shift_reg[10];
assign extra_loaddata = shift_reg;

endmodule

module testbench;
    reg txclk;
    reg ld;
    reg st;
    reg opn;
    reg sp;
    reg [7:0] d;
    wire TX;
    wire [10:0] extra_loaddata;
    
    STSystem_SR dut (
        .txclk(txclk),
        .ld(ld),
        .st(st),
        .opn(opn),
        .sp(sp),
        .d(d),
        .TX(TX),
        .extra_loaddata(extra_loaddata)
    );
    
    // Clock generation
    initial begin
        txclk = 0;
        forever #5 txclk = ~txclk;
    end
    
    initial begin
        // Initialize signals
        ld = 1; // start with ld high
        st = 0;
        opn = 0;
        sp = 1; // stop bit is 1
        d = 8'hAA; // 10101010
        
        // Wait a bit
        #10;
        
        // Apply load low for one clock cycle to load shift register
        @(negedge txclk);
        ld = 0;
        @(posedge txclk);
        @(negedge txclk);
        ld = 1;
        
        // Wait and observe shifting
        #200;
        $finish;
    end
endmodule
