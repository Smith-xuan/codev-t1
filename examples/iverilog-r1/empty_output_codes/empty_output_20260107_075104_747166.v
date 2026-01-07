// Verilog code that resulted in empty output
// Saved at: 2026-01-07T07:51:04.747194
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

// Sigma-Delta SPI Interface with Idle Timeout
module util_sigma_delta_spi #(
    parameter NUM_OF_CS = 1,          // Number of chip select lines
    parameter CS_PIN = 0,             // Which chip select line to monitor
    parameter IDLE_TIMEOUT = 100     // Number of clock cycles for inactivity timeout
) (
    input wire clk,
    input wire resetn,
    input wire spi_active,
    input wire s_sclk,
    input wire s_sdo,
    input wire s_sdo_t,
    input wire [NUM_OF_CS-1:0] s_cs,
    output reg s_sdi,
    output wire m_sclk,
    output reg m_sdo,
    output reg m_sdo_t,
    input wire m_sdi,
    output reg [NUM_OF_CS-1:0] m_cs,
    output reg data_ready
);

    // Synchronization registers for asynchronous SPI inputs
    reg [1:0] s_sclk_sync;
    reg [1:0] s_sdo_sync;
    reg [1:0] s_sdo_t_sync;
    reg [1:0] s_cs_sync;

    // Edge detection
    wire s_sclk_rising;
    wire s_sclk_falling;

    // Internal registers
    reg [7:0] rx_shift;          // receive shift register
    reg [7:0] tx_shift;          // transmit shift register
    reg [7:0] sampled_data;      // last sampled data from SPI (captured on transaction end)
    reg data_ready_reg;
    reg [31:0] timeout_counter;  // enough for timeout
    reg cs_active_delayed;       // debounced CS active
    reg rx_active;               // active receiving state

    // Default master outputs
    assign m_sclk = 1'b0;
    assign m_cs = {NUM_OF_CS{1'b1}};  // inactive high

    // Initialize
    initial begin
        s_sdi = 1'b0;
        m_sdo = 1'b1;      // pull up
        m_sdo_t = 1'b0;
        data_ready = 1'b0;
        rx_shift = 8'h00;
        tx_shift = 8'h00;
        sampled_data = 8'h00;
        timeout_counter = 0;
        cs_active_delayed = 1'b0;
        rx_active = 1'b0;
    end

    // Synchronize async inputs
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_sclk_sync <= 2'b00;
            s_sdo_sync <= 2'b00;
            s_sdo_t_sync <= 2'b00;
            s_cs_sync <= 2'b11;
        end else begin
            s_sclk_sync <= {s_sclk_sync[0], s_sclk};
            s_sdo_sync <= {s_sdo_sync[0], s_sdo};
            s_sdo_t_sync <= {s_sdo_t_sync[0], s_sdo_t};
            s_cs_sync[0] <= s_cs[CS_PIN];
            s_cs_sync[1] <= s_cs_sync[0];
        end
    end

    // Edge detection
    assign s_sclk_rising = (s_sclk_sync[1] == 1'b0 && s_sclk_sync[0] == 1'b1);
    assign s_sclk_falling = (s_sclk_sync[1] == 1'b1 && s_sclk_sync[0] == 1'b0);

    // Detect CS active (low)
    wire cs_sync_active = (s_cs_sync[1] == 1'b0);

    // Detect receiving condition: CS active, master sending (T=1)
    wire rx_cond = cs_sync_active && (s_sdo_t_sync[0] == 1'b1);

    // SPI slave logic
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cs_active_delayed <= 1'b0;
            rx_active <= 1'b0;
            rx_shift <= 8'h00;
            tx_shift <= 8'h00;
        end else begin
            // Debounce CS
            cs_active_delayed <= cs_sync_active;

            // Determine if we are currently in a receiving transaction
            rx_active <= rx_cond;

            // Sample data from master on rising edge of s_sclk
            if (s_sclk_rising && rx_cond) begin
                rx_shift <= {rx_shift[6:0], s_sdi};
            end

            // Shift out data on falling edge when slave transmitting (T=0)
            if (s_sclk_falling && (s_sdo_t_sync[0] == 1'b0) && cs_sync_active) begin
                // Echo received data (simple echo)
                s_sdi <= tx_shift[7];
                tx_shift <= {1'b0, tx_shift[7:1]};
            end

            // At end of transaction (CS goes inactive), latch captured data
            if (!cs_sync_active && cs_active_delayed) begin
                sampled_data <= rx_shift;
                rx_shift <= 8'h00;
                tx_shift <= 8'h00;
            end
        end
    end

    // Idle timeout logic using spi_active input
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            timeout_counter <= 0;
            data_ready_reg <= 1'b0;
            data_ready <= 1'b0;
        end else begin
            // Default assignments
            data_ready <= data_ready_reg;
            data_ready_reg <= 1'b0;

            // Reset counter when spi_active is high
            if (spi_active) begin
                timeout_counter <= 0;
            end else begin
                if (timeout_counter == IDLE_TIMEOUT - 1) begin
                    data_ready_reg <= 1'b1;
                    data_ready <= 1'b1;
                    // On data_ready pulse, output the sampled data
                    // Could also output on m_sdi? Not needed.
                end else begin
                    timeout_counter <= timeout_counter + 1;
                end
            end
        end
    end

endmodule

// Testbench
module testbench;
    reg clk;
    reg resetn;
    reg spi_active;
    reg s_sclk;
    reg s_sdo;
    reg s_sdo_t;
    reg [0:0] s_cs;
    wire s_sdi;
    wire m_sclk;
    wire m_sdo;
    wire m_sdo_t;
    reg m_sdi;
    wire [0:0] m_cs;
    wire data_ready;

    // Instantiate DUT with smaller timeout for simulation
    util_sigma_delta_spi #(
        .NUM_OF_CS(1),
        .CS_PIN(0),
        .IDLE_TIMEOUT(10)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .spi_active(spi_active),
        .s_sclk(s_sclk),
        .s_sdo(s_sdo),
        .s_sdo_t(s_sdo_t),
        .s_cs(s_cs),
        .s_sdi(s_sdi),
        .m_sclk(m_sclk),
        .m_sdo(m_sdo),
        .m_sdo_t(m_sdo_t),
        .m_sdi(m_sdi),
        .m_cs(m_cs),
        .data_ready(data_ready)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test procedure
    integer i;
    reg [7:0] master_data;
    reg [7:0] captured_data;
    integer data_ready_width;
    reg data_ready_history [0:9];
    integer ready_pulse_count;
    initial begin
        // Initialize
        clk = 0;
        resetn = 0;
        spi_active = 0;
        s_sclk = 0;
        s_sdo = 0;
        s_sdo_t = 0;
        s_cs = 1;  // inactive (high) - active low
        m_sdi = 0;
        master_data = 8'hAA;  // pattern to send
        captured_data = 8'h00;
        data_ready_width = 0;
        ready_pulse_count = 0;
        #20;

        // Release reset
        resetn = 1;
        #20;

        // Simulate SPI master sending data
        // Configure for master transmission: T=1 (master drives SDO), CS active low
        s_cs = 0;  // assert CS
        s_sdo_t = 1; // master drives SDO
        // Send 8 bits: master_data
        spi_active = 1; // indicate SPI active
        
        // Clock 8 bits
        for (i = 0; i < 8; i = i + 1) begin
            // Set SDO data before rising edge
            s_sdo = master_data[i];
            #10 s_sclk = 1; // rising edge - sample SDI
            #10 s_sclk = 0; // falling edge - change SDO if needed
            // Master does not need to drive SDI during write
            // Let slave drive SDI (we'll monitor)
        end

        // Deassert CS after transaction
        spi_active = 0;
        #20 s_cs = 1;
        
        // Wait for idle timeout (10 cycles) -> data_ready should pulse
        #200; // wait enough time

        // Check data_ready pulsed
        if (ready_pulse_count == 1) $display("PASS: data_ready pulsed exactly once after timeout");
        else if (ready_pulse_count > 0) $display("FAIL: data_ready pulsed %0d times, expected 1", ready_pulse_count);
        else $display("FAIL: data_ready never pulsed");

        // Display captured data
        $display("Captured data: %h", dut.sampled_data);

        // End simulation
        $finish;
    end

    // Monitor data_ready pulses
    always @(posedge clk) begin
        data_ready_history[data_ready_width] <= data_ready;
        if (data_ready) begin
            ready_pulse_count = ready_pulse_count + 1;
            $display("Data ready pulse at time %0t", $time);
        end
    end

    integer width;
    initial begin
        width = 0;
        forever begin
            @(posedge clk);
            width = width + 1;
            if (width > 20) $finish;
        end
    end

endmodule
