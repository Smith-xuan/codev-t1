// Verilog code that resulted in empty output
// Saved at: 2026-01-13T22:30:28.480672
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

module sort (
    input en,
    input [3:0] a1, a2, a3, a4, a5,
    output reg [3:0] o1, o2, o3, o4, o5
);

wire [3:0] a [0:4];
assign a[0] = a1;
assign a[1] = a2;
assign a[2] = a3;
assign a[3] = a4;
assign a[4] = a5;

always @(posedge en) begin
    reg [3:0] elem [0:4];
    integer i, j;
    // copy inputs
    elem[0] = a1;
    elem[1] = a2;
    elem[2] = a3;
    elem[3] = a4;
    elem[4] = a5;
    
    // bubble sort descending
    for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4 - i; j = j + 1) begin
            if (elem[j] < elem[j+1]) begin
                // swap
                elem[j] = elem[j+1];
                elem[j+1] = elem[j];
            end
        end
    end
    
    // assign outputs
    o5 = elem[0]; // largest
    o4 = elem[1];
    o3 = elem[2];
    o2 = elem[3];
    o1 = elem[4]; // smallest
end

endmodule

module testbench;
reg en;
reg [3:0] a1, a2, a3, a4, a5;
wire [3:0] o1, o2, o3, o4, o5;

sort dut (
    .en(en),
    .a1(a1),
    .a2(a2),
    .a3(a3),
    .a4(a4),
    .a5(a5),
    .o1(o1),
    .o2(o2),
    .o3(o3),
    .o4(o4),
    .o5(o5)
);

initial begin
    // Test case 1: random values
    en = 0;
    a1 = 4'd5;
    a2 = 4'd9;
    a3 = 4'd3;
    a4 = 4'd7;
    a5 = 4'd2;
    @(posedge en);
    // wait a bit after posedge
    #10;
    $display("Test 1: inputs %d %d %d %d %d", a1, a2, a3, a4, a5);
    $display("  Outputs: o5=%d, o4=%d, o3=%d, o2=%d, o1=%d", o5, o4, o3, o2, o1);
    // Expected sorted descending: 9,7,5,4,3? Wait values: 5,9,3,7,2 => sorted: 9,7,5,3,2
    if (o5 !== 9 || o4 !== 7 || o3 !== 5 || o2 !== 3 || o1 !== 2) begin
        $display("  ERROR: mismatch");
        $finish;
    end else begin
        $display("  PASS");
    end
    
    // Test case 2: already sorted descending
    en = 0;
    #10;
    a1 = 4'd10;
    a2 = 4'd9;
    a3 = 4'd8;
    a4 = 4'd7;
    a5 = 4'd6;
    @(posedge en);
    #10;
    $display("Test 2: inputs %d %d %d %d %d", a1, a2, a3, a4, a5);
    $display("  Outputs: o5=%d, o4=%d, o3=%d, o2=%d, o1=%d", o5, o4, o3, o2, o1);
    if (o5 !== 10 || o4 !== 9 || o3 !== 8 || o2 !== 7 || o1 !== 6) begin
        $display("  ERROR: mismatch");
        $finish;
    end else begin
        $display("  PASS");
    end
    
    // Test case 3: ascending order
    en = 0;
    #10;
    a1 = 4'd1;
    a2 = 4'd2;
    a3 = 4'd3;
    a4 = 4'd4;
    a5 = 4'd5;
    @(posedge en);
    #10;
    $display("Test 3: inputs %d %d %d %d %d", a1, a2, a3, a4, a5);
    $display("  Outputs: o5=%d, o4=%d, o3=%d, o2=%d, o1=%d", o5, o4, o3, o2, o1);
    if (o5 !== 5 || o4 !== 4 || o3 !== 3 || o2 !== 2 || o1 !== 1) begin
        $display("  ERROR: mismatch");
        $finish;
    end else begin
        $display("  PASS");
    end
    
    // Test case 4: equal values
    en = 0;
    #10;
    a1 = 4'd3;
    a2 = 4'd3;
    a3 = 4'd3;
    a4 = 4'd3;
    a5 = 4'd3;
    @(posedge en);
    #10;
    $display("Test 4: inputs %d %d %d %d %d", a1, a2, a3, a4, a5);
    $display("  Outputs: o5=%d, o4=%d, o3=%d, o2=%d, o1=%d", o5, o4, o3, o2, o1);
    if (o5 !== 3 || o4 !== 3 || o3 !== 3 || o2 !== 3 || o1 !== 3) begin
        $display("  ERROR: mismatch");
        $finish;
    end else begin
        $display("  PASS");
    end
    
    // Test case 5: extreme values (0 and 15)
    en = 0;
    #10;
    a1 = 4'd0;
    a2 = 4'd15;
    a3 = 4'd15;
    a4 = 4'd15;
    a5 = 4'd0;
    @(posedge en);
    #10;
    $display("Test 5: inputs %d %d %d %d %d", a1, a2, a3, a4, a5);
    $display("  Outputs: o5=%d, o4=%d, o3=%d, o2=%d, o1=%d", o5, o4, o3, o2, o1);
    if (o5 !== 15 || o4 !== 15 || o3 !== 15 || o2 !== 0 || o1 !== 0) begin
        $display("  ERROR: mismatch");
        $finish;
    end else begin
        $display("  PASS");
    end
    
    $display("All tests passed");
    $finish;
end
endmodule
