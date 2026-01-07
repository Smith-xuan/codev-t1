// Verilog code that resulted in empty output
// Saved at: 2026-01-06T08:06:19.733926
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

// counter_point5sec with parameters for simulation scaling
module counter_point5sec #(
    parameter CLK_PERIOD_NS = 500_000_000,  // sets half-second cycles = 1 for simulation
    parameter FRAME_COUNT_MAX = 30
) (
    input wire clk,
    input wire enable_my_counter,
    output wire enable_next
);
    wire reset = ~enable_my_counter; // active high reset when enable_my_counter low
    
    wire enable_frame;
    
    // Compute half-second cycles
    localparam HALF_SECOND_CYCLES = 1; // since CLK_PERIOD_NS = 0.5 sec, half second cycles = 1
    
    // Instantiate Delay_Counter5 (simplified)
    // Actually we can combine into one module, but let's keep submodules for structure
    // Let's create a combined module for simulation simplicity.
    // But we need submodules as per problem: Delay_Counter5 and Frame_Counter5.
    // Let's implement them.
    
    // Delay_Counter5
    Delay_Counter5 #(
        .CLK_PERIOD_NS(CLK_PERIOD_NS)
    ) delay_inst (
        .clk(clk),
        .reset(reset),
        .enable_frame(enable_frame)
    );
    
    // Frame_Counter5
    Frame_Counter5 #(
        .FRAME_COUNT_MAX(FRAME_COUNT_MAX)
    ) frame_inst (
        .clk(clk),
        .reset(reset),
        .enable_frame(enable_frame),
        .enable_next(enable_next)
    );
endmodule

// Delay_Counter5 module that counts clock cycles to generate enable_frame every 0.5 seconds
module Delay_Counter5 #(
    parameter CLK_PERIOD_NS = 500_000_000
) (
    input wire clk,
    input wire reset,          // active high
    output reg enable_frame
);
    // half second cycles = 0.5 sec / (CLK_PERIOD_NS * 1e-9) cycles
    // Compute using integer arithmetic (in nanoseconds)
    localparam HALF_SECOND_CYCLES = (500_000_000 * CLK_PERIOD_NS) / 1_000_000_000;
    localparam COUNTER_WIDTH = $clog2(HALF_SECOND_CYCLES) + 1;
    reg [COUNTER_WIDTH-1:0] counter;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            enable_frame <= 0;
        end else begin
            if (counter == HALF_SECOND_CYCLES - 1) begin
                counter <= 0;
                enable_frame <= 1;
            end else begin
                counter <= counter + 1;
                enable_frame <= 0;
            end
        end
    end
endmodule

// Frame_Counter5 module
module Frame_Counter5 #(
    parameter FRAME_COUNT_MAX = 30
) (
    input wire clk,
    input wire reset,          // active high
    input wire enable_frame,
    output reg enable_next
);
    localparam COUNTER_WIDTH = $clog2(FRAME_COUNT_MAX) + 1;
    reg [COUNTER_WIDTH-1:0] counter;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            enable_next <= 0;
        end else begin
            if (enable_frame) begin
                if (counter == FRAME_COUNT_MAX - 1) begin
                    counter <= 0;
                    enable_next <= 1;
                end else begin
                    counter <= counter + 1;
                    enable_next <= 0;
                end
            end else begin
                enable_next <= 0;
            end
        end
    end
endmodule

// Testbench with scaled parameters for simulation
module testbench;
    reg clk;
    reg enable_my_counter;
    wire enable_next;
    
    // Instantiate DUT with parameters that give small counts for simulation
    // Set CLK_PERIOD_NS such that half-second cycles = 1 (so enable_frame pulses every clock)
    // Set FRAME_COUNT_MAX = 5 for easier simulation
    parameter SIM_CLK_PERIOD_NS = 500_000_000; // 0.5 sec => half second cycles = 1
    parameter SIM_FRAME_COUNT_MAX = 5; // instead of 30, use 5 for faster simulation
    
    // Note: The DUT parameter FRAME_COUNT_MAX is defaulted to 30, but we can override.
    // However, the DUT top module's parameters are CLk_PERIOD_NS and FRAME_COUNT_MAX.
    // We'll need to instantiate DUT with overridden parameters.
    // Let's do that.
    
    // Generate clock with period matching SIM_CLK_PERIOD_NS
    real clk_period_ns = SIM_CLK_PERIOD_NS; // In ns
    // Clock frequency based on this period
    // We'll generate a clock with period 2 * clk_period_ns? Actually clock period is clk_period_ns for half cycle? Let's define clock with period = clk_period_ns (i.e., time for one full cycle).
    // We'll use real time delays.
    // Let's generate a clock with period = clk_period_ns (half period = clk_period_ns/2)
    // We'll set clk_period_ns = 1000 ns for simplicity.
    
    // Let's change SIM_CLK_PERIOD_NS to 1000 ns (1 μs) for simulation.
    // Then half second cycles = 0.5 sec / 1 μs = 500 cycles. Still large.
    // Wait: CLK_PERIOD_NS = 500_000_000 (0.5 sec). That means clock period is 0.5 seconds => half second cycles = 1.
    // That's fine. We'll use that.
    // But we need to generate a clock with period = 0.5 seconds? That's 500 ms period, simulation will be long.
    // Let's use a clock period of 1 ms (1,000,000 ns). Then half second cycles = 0.5 / 0.001 = 500 cycles.
    // That's still large but manageable? We'll run a few cycles.
    
    // Let's decide: For simulation, we want to see enable_next pulse after 30 enable_frame pulses.
    // If enable_frame pulses every clock, we need 30 clock cycles. That's okay if clock period is say 10 ns => 300 ns simulation time.
    // So we need CLK_PERIOD_NS = 10 ns? Then half second cycles = 0.5 / 10e-9 = 50,000,000 cycles. Not good.
    // Actually we want half-second cycles to be something like 10. So we need CLK_PERIOD_NS such that half second cycles = 10.
    // That means CLK_PERIOD_NS = 0.5 / 10 = 0.05 sec = 50,000,000 ns.
    // That's large. Not good for simulation.
    
    // Better approach: We'll keep the DUT's internal half-second cycles computed from parameter, but in testbench we'll set the parameter to a small value.
    // Let's make CLK_PERIOD_NS = 100,000,000 ns (0.1 sec). Then half second cycles = 0.5 / 0.1 = 5 cycles.
    // That's manageable.
    
    // Let's set SIM_CLK_PERIOD_NS = 100_000_000 ns = 0.1 sec.
    // Then half_second_cycles = 5.
    // Clock period is 0.1 sec, so each clock tick is 100 ms. Simulation of 5 cycles = 500 ms simulation time? No, each clock period is 100 ms, so 5 cycles = 500 ms simulation time. That's okay.
    
    // Let's implement that.
    
    // Define clock with period = SIM_CLK_PERIOD_NS (in ns)
    // We'll generate clock with period = SIM_CLK_PERIOD_NS * 1e-9 seconds? Actually we can use real time delays in testbench.
    // We'll set clk_period = SIM_CLK_PERIOD_NS * 1e-9? Wait, we can just use # delays in ns.
    // Let's set a clock with period = 100_000_000 ns = 100 ms. That means half period = 50 ms.
    // We'll use non-blocking assignments with # delays.
    
    // Let's write code.
    parameter CLK_PERIOD_NS = 100_000_000; // 0.1 sec
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS / 2);
        clk = ~clk;
    end
    
    // DUT instance with overridden parameters
    counter_point5sec #(
        .CLK_PERIOD_NS(CLK_PERIOD_NS),
        .FRAME_COUNT_MAX(SIM_FRAME_COUNT_MAX)
    ) dut (
        .clk(clk),
        .enable_my_counter(enable_my_counter),
        .enable_next(enable_next)
    );
    
    // Test sequence
    initial begin
        // Initialize
        enable_my_counter = 0;
        // Wait a few clock edges
        #100;
        // Release reset
        enable_my_counter = 1;
        // Wait for many clock cycles to observe enable_next pulse
        // We expect enable_next after 5 enable_frame pulses (since FRAME_COUNT_MAX = 5)
        // Let's wait for 10 clock cycles.
        #(CLK_PERIOD_NS * 10);
        // Check that enable_next pulsed after 5 pulses (should have pulsed)
        // We'll also test reset.
        enable_my_counter = 0;
        #(CLK_PERIOD_NS * 2);
        enable_my_counter = 1;
        #(CLK_PERIOD_NS * 10);
        $finish;
    end
    
    // Monitor signals
    integer frame_count = 0;
    integer next_count = 0;
    always @(posedge clk) begin
        if (enable_my_counter) begin
            if (dut.delay_inst.enable_frame) begin
                frame_count = frame_count + 1;
                $display("Frame pulse %0d at time %0t ns", frame_count, $time);
            end
            if (enable_next) begin
                next_count = next_count + 1;
                $display("enable_next pulse %0d at time %0t ns", next_count, $time);
            end
        end
    end
    
endmodule
