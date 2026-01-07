
module posedge_detector_gate (
    input  clk,
    input  signal,
    output reg posedge_detected
);
    reg signal_sync1, signal_sync2;
    reg signal_delayed;
    always @(posedge clk) begin
        signal_sync1 <= signal;
        signal_sync2 <= signal_sync1;
        signal_delayed <= signal_sync2;
        posedge_detected <= signal_sync2 & ~signal_delayed;
    end
endmodule