module posedge_detector (
    input wire clk,
    input wire signal,
    output wire posedge_detected
);
    reg signal_prev;
    always @(posedge clk) begin
        signal_prev <= signal;
    end
    assign posedge_detected = (signal == 1'b1) && (signal_prev == 1'b0);
endmodule