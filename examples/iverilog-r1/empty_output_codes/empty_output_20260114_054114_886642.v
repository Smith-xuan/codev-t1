// Verilog code that resulted in empty output
// Saved at: 2026-01-14T05:41:14.886669
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

module spi_slave (
    input sclk,
    input mosi,
    input [7:0] ss_pad_o,
    output miso,
    input rx_slave,
    input tx_slave
);

reg [127:0] temp1, temp2;
reg miso1, miso2;

wire rx_mode = rx_slave && !tx_slave;
wire tx_mode = tx_slave && !rx_slave;

// receive mode: shift on rising edge
always @(posedge sclk) begin
    if (ss_pad_o != 8'b11111111) begin
        if (rx_mode) begin
            // shift right, insert mosi at MSB
            temp1 <= {mosi, temp1[127:1]};
        end
        // miso2 update on rising edge (MSB of temp2)
        miso2 <= temp2[127];
    end
end

// transmit mode: shift on falling edge, update miso1 on falling edge
always @(negedge sclk) begin
    if (ss_pad_o != 8'b11111111) begin
        if (tx_mode) begin
            temp2 <= {mosi, temp2[127:1]};
        end
        // miso1 update on falling edge: MSB of temp1 (which may have been updated on rising edge)
        miso1 <= temp1[127];
    end
end

assign miso = miso1 | miso2;

endmodule

module testbench;
reg sclk;
reg mosi;
reg [7:0] ss_pad_o;
wire miso;
reg rx_slave, tx_slave;

spi_slave dut (
    .sclk(sclk),
    .mosi(mosi),
    .ss_pad_o(ss_pad_o),
    .miso(miso),
    .rx_slave(rx_slave),
    .tx_slave(tx_slave)
);

initial begin
    // Initialize signals
    sclk = 0;
    mosi = 0;
    ss_pad_o = 8'b11111111; // deasserted
    rx_slave = 0;
    tx_slave = 0;
    
    // Wait a bit
    #10;
    
    // Assert slave select (any bit not high, e.g., bit 0 low)
    ss_pad_o = 8'b11111110;
    
    // Test receive mode: rx=1, tx=0
    rx_slave = 1;
    tx_slave = 0;
    
    // Drive MOSI with pattern 0,1,0,1...
    // Clock cycle 1: rising edge, shift in 0
    mosi = 0;
    #5; // wait half clock (sclk becomes 1?) We'll toggle sclk
    // Let's create a clock with period 10 time units
    // Start with sclk low
    #5 sclk = 1; // first rising edge
    #5 sclk = 0; // falling edge
    
    // Check internal temp1 after first rising edge: should have 0 at MSB
    // We can't directly access internal signals from testbench; we can infer via miso?
    
    // Second rising edge
    #5 sclk = 1; // rising edge
    mosi = 1;
    #5 sclk = 0;
    
    // Third rising edge
    mosi = 0;
    #5 sclk = 1;
    #5 sclk = 0;
    
    // Stop
    #10 $finish;
end

endmodule
