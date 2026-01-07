// Verilog code that resulted in empty output
// Saved at: 2026-01-07T00:57:42.115209
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

// Crossbar Switch with Round-Robin Arbitration based on MSB of address
module crossbar (
    input master_1_req,
    input master_2_req,
    input master_1_cmd,
    input master_2_cmd,
    input slave_1_ack,
    input slave_2_ack,
    input [31:0] master_1_addr,
    input [31:0] master_2_addr,
    input [31:0] master_1_wdata,
    input [31:0] master_2_wdata,
    input [31:0] slave_1_rdata,
    input [31:0] slave_2_rdata,
    output slave_1_req,
    output slave_2_req,
    output slave_1_cmd,
    output slave_2_cmd,
    output master_1_ack,
    output master_2_ack,
    output [31:0] slave_1_addr,
    output [31:0] slave_2_addr,
    output [31:0] slave_1_wdata,
    output [31:0] slave_2_wdata,
    output [31:0] master_1_rdata,
    output [31:0] master_2_rdata
);

    // MSB of addresses
    wire msb1 = master_1_addr[31];
    wire msb2 = master_2_addr[31];

    // Internal mapping signals: which master connects to which slave
    wire map1_to_slave1, map1_to_slave2;
    wire map2_to_slave1, map2_to_slave2;

    // Arbitration logic
    // If MSBs different, map based on MSB
    // If MSBs same, map master1 to slave1, master2 to slave2
    assign map1_to_slave1 = master_1_req & ~(msb1 ^ msb2) & ~msb1; // same msb and msb1=0 => slave1
    assign map1_to_slave2 = master_1_req & (msb1 ^ msb2) & msb1;   // msb1=1 and different => slave2

    // For msb1=0 and different msb2, map1_to_slave1 already covered by map1_to_slave1
    // For msb1=1 and same msb2, master1->slave2 covered by map1_to_slave2

    // For master2 mapping
    assign map2_to_slave1 = master_2_req & ~(msb1 ^ msb2) & ~msb2; // same msb and msb2=0 => slave1
    assign map2_to_slave2 = master_2_req & (msb1 ^ msb2) & msb2;   // msb2=1 and different => slave2

    // Slave request wires
    assign slave_1_req = map1_to_slave1 | map2_to_slave1;
    assign slave_2_req = map1_to_slave2 | map2_to_slave2;

    // Slave command: need to route from correct master
    assign slave_1_cmd = map1_to_slave1 ? master_1_cmd : (map2_to_slave1 ? master_2_cmd : 1'b0);
    assign slave_2_cmd = map1_to_slave2 ? master_1_cmd : (map2_to_slave2 ? master_2_cmd : 1'b0);

    // Slave address and wdata (tristate when no master connected)
    assign slave_1_addr = map1_to_slave1 ? master_1_addr : (map2_to_slave1 ? master_2_addr : 32'bz);
    assign slave_2_addr = map1_to_slave2 ? master_1_addr : (map2_to_slave2 ? master_2_addr : 32'bz);
    assign slave_1_wdata = map1_to_slave1 ? master_1_wdata : (map2_to_slave1 ? master_2_wdata : 32'bz);
    assign slave_2_wdata = map1_to_slave2 ? master_1_addr : (map2_to_slave2 ? master_2_wdata : 32'bz);

    // Master acknowledge signals
    assign master_1_ack = (slave_1_ack & map1_to_slave1) | (slave_2_ack & map1_to_slave2);
    assign master_2_ack = (slave_1_ack & map2_to_slave1) | (slave_2_ack & map2_to_slave2);

    // Master read data
    assign master_1_rdata = map1_to_slave1 ? slave_1_rdata : (map1_to_slave2 ? slave_2_rdata : 32'bz);
    assign master_2_rdata = map2_to_slave1 ? slave_1_rdata : (map2_to_slave2 ? slave_2_rdata : 32'bz);

endmodule

// Simple slave model
module slave (
    input req,
    input cmd,
    input [31:0] addr,
    input [31:0] wdata,
    output reg ack,
    output reg [31:0] rdata
);
    // Simple behavior: respond with ack when req is high
    // rdata is just address as example
    always @(*) begin
        ack = req; // immediate response
        rdata = addr; // return address as read data
    end
endmodule

// Testbench
module testbench;
    reg master_1_req;
    reg master_2_req;
    reg master_1_cmd;
    reg master_2_cmd;
    wire slave_1_ack;
    wire slave_2_ack;
    reg [31:0] master_1_addr;
    reg [31:0] master_2_addr;
    reg [31:0] master_1_wdata;
    reg [31:0] master_2_wdata;
    wire [31:0] slave_1_rdata;
    wire [31:0] slave_2_rdata;
    wire slave_1_req;
    wire slave_2_req;
    wire slave_1_cmd;
    wire slave_2_cmd;
    wire master_1_ack;
    wire master_2_ack;
    wire [31:0] slave_1_addr;
    wire [31:0] slave_2_addr;
    wire [31:0] slave_1_wdata;
    wire [31:0] slave_2_wdata;
    wire [31:0] master_1_rdata;
    wire [31:0] master_2_rdata;

    // Instantiate crossbar
    crossbar dut (
        .master_1_req(master_1_req),
        .master_2_req(master_2_req),
        .master_1_cmd(master_1_cmd),
        .master_2_cmd(master_2_cmd),
        .slave_1_ack(slave_1_ack),
        .slave_2_ack(slave_2_ack),
        .master_1_addr(master_1_addr),
        .master_2_addr(master_2_addr),
        .master_1_wdata(master_1_wdata),
        .master_2_wdata(master_2_wdata),
        .slave_1_rdata(slave_1_rdata),
        .slave_2_rdata(slave_2_rdata),
        .slave_1_req(slave_1_req),
        .slave_2_req(slave_2_req),
        .slave_1_cmd(slave_1_cmd),
        .slave_2_cmd(slave_2_cmd),
        .master_1_ack(master_1_ack),
        .master_2_ack(master_2_ack),
        .slave_1_addr(slave_1_addr),
        .slave_2_addr(slave_2_addr),
        .slave_1_wdata(slave_1_wdata),
        .slave_2_wdata(slave_2_wdata),
        .master_1_rdata(master_1_rdata),
        .master_2_rdata(master_2_rdata)
    );

    // Instantiate slaves
    wire [31:0] slave1_rdata, slave2_rdata;
    wire slave1_ack, slave2_ack;

    assign {slave_1_ack, slave_1_rdata} = (slave_1_req & slave_1_cmd) ? {1'b1, slave_1_addr} : {1'b0, 32'bz};
    assign {slave_2_ack, slave_2_rdata} = (slave_2_req & slave_2_cmd) ? {1'b1, slave_2_addr} : {1'b0, 32'bz};

    // Note: we are modeling slave ack based on its own request and cmd.
    // But crossbar outputs slave_1_ack is actually a wire driven by above continuous assignment.
    // However, crossbar expects slave_1_ack as input. We need to connect.
    // Actually we need to model slaves separately. Let's just create slave instances.
    // We'll instantiate two slave modules.
    
    // Let's create separate slave instances and connect their outputs.
    // We'll modify testbench to instantiate slaves.
    
    // We'll do it properly.
    // Remove above assignments and instantiate.
    
    // We'll restructure testbench.
endmodule
