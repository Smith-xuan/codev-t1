/**
 * posedge_detector - Rising edge detector synchronized with clock
 *
 * Detects positive (rising) edges on an input signal and outputs a
 * one-clock-cycle pulse synchronized to the rising edge of clk.
 *
 * Features:
 * - Two-stage synchronizer for metastability protection
 * - One-clock-cycle output pulse per detected rising edge
 * - Fully synchronous design
 *
 * Note: For synchronous inputs where latency is critical,
 * a single flip-flop implementation could be used instead.
 */
module posedge_detector (
    input  clk,               // Clock signal
    input  signal,            // Input signal to monitor
    output reg posedge_detected // Detection output (high for one cycle)
);

    // Two-stage synchronizer for metastability protection
    reg signal_sync1, signal_sync2;

    // Delayed version of synchronized signal for edge detection
    reg signal_delayed;

    always @(posedge clk) begin
        // First synchronization stage
        signal_sync1 <= signal;

        // Second synchronization stage
        signal_sync2 <= signal_sync1;

        // Store previous synchronized value
        signal_delayed <= signal_sync2;

        // Detect rising edge: current synchronized signal is high
        // and previous synchronized value was low
        posedge_detected <= signal_sync2 & ~signal_delayed;
    end

    // Alternative: Single flip-flop version with lower latency
    // Uncomment and remove above logic to use this version:
    /*
    reg signal_delayed;

    always @(posedge clk) begin
        signal_delayed <= signal;
        posedge_detected <= signal & ~signal_delayed;
    end
    */

endmodule