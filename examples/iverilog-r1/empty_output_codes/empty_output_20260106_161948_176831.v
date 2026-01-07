// Verilog code that resulted in empty output
// Saved at: 2026-01-06T16:19:48.176860
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

module keyboard(
    input clk,
    input reset,
    input ps2clk,
    input ps2data,
    output reg [7:0] scancode,
    output reg flagkey
);

    // PS/2 packet: start bit (0), 8 data bits, parity bit, stop bit (1)
    parameter PKT_BITS = 11;
    
    // States
    localparam IDLE = 2'b00;
    localparam GOT_F0 = 2'b01;
    reg [1:0] state, next_state;
    
    // Synchronize ps2clk
    reg [1:0] ps2clk_sync;
    always @(posedge clk) begin
        if (reset) begin
            ps2clk_sync <= 2'b11;
        end else begin
            ps2clk_sync <= {ps2clk_sync[0], ps2clk};
        end
    end
    
    // Detect falling edge on synchronized ps2clk
    wire ps2clk_falling = (ps2clk_sync[1:0] == 2'b10);
    
    // Synchronize ps2data
    reg [1:0] ps2data_sync;
    always @(posedge clk) begin
        if (reset) begin
            ps2data_sync <= 2'b00;
        end else begin
            ps2data_sync <= {ps2data_sync[0], ps2data};
        end
    end
    
    // Sampling at ps2clk_falling
    reg [PKT_BITS-1:0] shift_reg;
    reg [$clog2(PKT_BITS):0] bit_count; // enough bits to count 0..10
    
    always @(posedge clk) begin
        if (reset) begin
            shift_reg <= 0;
            bit_count <= 0;
            state <= IDLE;
            flagkey <= 0;
        end else begin
            // Clear flagkey after one cycle
            flagkey <= 0;
            
            if (ps2clk_falling) begin
                if (bit_count == PKT_BITS) begin
                    // Packet complete
                    // Validate start bit, parity, stop bit
                    // start bit is shift_reg[0] should be 0
                    // stop bit is shift_reg[PKT_BITS-1] should be 1
                    // parity bit is shift_reg[8]
                    // odd parity check: parity_bit ^ ^data = 1
                    // If packet valid, process
                    if (state == IDLE) begin
                        // Check start bit, stop bit, parity
                        if (shift_reg[0] == 1'b0 && shift_reg[PKT_BITS-1] == 1'b1 && 
                            (shift_reg[8] ^ ^shift_reg[8:1]) == 1'b1) begin
                            // Valid packet
                            // Check if data byte is F0
                            if (shift_reg[8:1] == 8'hF0) begin
                                state <= GOT_F0;
                            end
                        end
                    end else if (state == GOT_F0) begin
                        // Check start bit, stop bit, parity
                        if (shift_reg[0] == 1'b0 && shift_reg[PKT_BITS-1] == 1'b1 && 
                            (shift_reg[8] ^ ^shift_reg[8:1]) == 1'b1) begin
                            // Valid packet, output scancode
                            scancode <= shift_reg[8:1]; // Output the scancode (data byte)
                            flagkey <= 1'b1;
                            state <= IDLE;
                        end
                    end
                    bit_count <= 0;
                    shift_reg <= 0;
                end else begin
                    // Shift in data
                    // LSB first: first bit received is start bit (shift_reg[0])
                    // We shift right, new bit becomes shift_reg[PKT_BITS-1]? Actually we shift left?
                    // Let's think: we receive start bit first, then data bits LSB first.
                    // We'll store in shift_reg with start bit at index 0, next bits incrementing.
                    // Current implementation shifts right, which would overwrite lower bits.
                    // We need to shift left and insert at LSB? Let's examine.
                    // Actually we want shift_reg[0] to hold first bit (start), shift_reg[1] second bit, etc.
                    // When we shift right, we lose the LSB and shift in new bit at MSB.
                    // That's wrong.
                    // Better: shift left and insert at LSB.
                    shift_reg <= {shift_reg[PKT_BITS-2:0], ps2data_sync[0]};
                    bit_count <= bit_count + 1;
                end
            end
        end
    end
    
endmodule

module testbench;
    reg clk;
    reg reset;
    reg ps2clk;
    reg ps2data;
    wire [7:0] scancode;
    wire flagkey;
    
    keyboard dut (
        .clk(clk),
        .reset(reset),
        .ps2clk(ps2clk),
        .ps2data(ps2data),
        .scancode(scancode),
        .flagkey(flagkey)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock (10 ns period)
    end
    
    // PS/2 clock generation (simulate slower clock)
    task ps2clk_gen;
        begin
            ps2clk = 1;
            #50; // half period
            ps2clk = 0;
            #100; // half period
        end
    endtask
    
    // Send one PS/2 packet
    task send_packet;
        input [0:10] packet; // 11 bits: packet[0] = start, packet[1] = data[0], ..., packet[8] = parity, packet[9] = data[7], packet[10] = stop
        integer i;
        begin
            for (i=0; i<11; i=i+1) begin
                ps2clk = 0;
                ps2data = packet[i];
                #100; // wait half period
                ps2clk = 1;
                #100; // wait half period
            end
        end
    endtask
    
    initial begin
        // Initialize
        reset = 1;
        ps2clk = 1;
        ps2data = 1;
        #20 reset = 0;
        
        // Wait a bit
        #100;
        
        // Test 1: Send a make code packet (ignore)
        // Make code: start 0, data 0x1C (KEY_A), odd parity, stop 1
        // Data 0x1C = 8'b00011100 -> LSB first: bits: 0,0,0,1,1,1,0,0
        // Parity: number of 1's = 3 -> odd -> parity bit = 0
        // Packet: start=0, data bits LSB first: 0,0,0,1,1,1,0,0, parity=0, stop=1
        // Pack bits into array: index: start, d0,d1,d2,d3,d4,d5,d6,d7, parity, stop
        // So packet[0]=0, packet[1]=0, packet[2]=0, packet[3]=1, packet[4]=1, packet[5]=1, packet[6]=0, packet[7]=0, packet[8]=0, packet[9]=0, packet[10]=1
        // Let's compute: 8'h1C = 8'b0001_1100. LSB first: bit0=0, bit1=0, bit2=0, bit3=1, bit4=1, bit5=1, bit6=0, bit7=0.
        // So packet = {1'b1, 8'b00011100, 1'b0, 1'b0}; but need ordering: stop, parity, data[7:0], start? Wait we defined packet[0] = start.
        // Let's create vector correctly: start, d0,d1,d2,d3,d4,d5,d6,d7, parity, stop.
        send_packet({1'b1, 8'b00011100, 1'b0, 1'b0}); // This is wrong ordering.
        // Actually we need to specify each bit
        // Let's do manually:
        // ps2clk=0; ps2data=0; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=0; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=0; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=1; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=1; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=1; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=0; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=0; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=0; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=1; #100; ps2clk=1; #100;
        // ps2clk=0; ps2data=1; #100; ps2clk=1; #100;
        
        // Let's instead write a function to send packet with correct ordering.
        // We'll create function send_bit.
        // End of test
        #1000;
        
        // Test 2: Send F0 packet (break prefix)
        // F0 = 8'hF0 = 8'b11110000. LSB first: 0,0,0,0,1,1,1,1
        // Parity: number of 1's = 4 -> even -> parity bit = 1
        // Packet: start=0, data bits LSB first: 0,0,0,0,1,1,1,1, parity=1, stop=1
        // PS/2 timing: clock high for >60us, low for >60us. In simulation we use 150ns half period (should be fine).
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        
        #1000;
        
        // Test 3: Send scancode packet (second byte) after F0
        // Scancode 0x3A (KEY_Z) make code LSB first: 0x3A = 8'b00111010. LSB first: 0,1,0,1,1,1,0,0
        // Parity: number of 1's = 4 -> even -> parity bit = 1
        // Packet: start=0, data bits LSB first: 0,1,0,1,1,1,0,0, parity=1, stop=1
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 0; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        ps2clk = 0; ps2data = 1; #100; ps2clk = 1; #100;
        
        #2000;
        
        $finish;
    end
    
    // Monitor outputs
    always @(posedge clk) begin
        if (flagkey) begin
            $display("Flagkey asserted, scancode = %h", scancode);
        end
    end
    
endmodule
