`include "macro.v"
module Regfile (
    input clk,
    input rst,
    
    // Read ports
    input [4:0] rs1_addr,
    input [4:0] rs2_addr,
    output [`XLEN-1:0] rs1_data,
    output [`XLEN-1:0] rs2_data,
    
    // Write port
    input we,
    input [4:0] rd_addr,
    input [`XLEN-1:0] rd_data
);

    reg [`XLEN-1:0] regs [`NREGS-1:0];
    
    integer i;
    
    // Reset all registers
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `NREGS; i = i + 1) begin
                regs[i] <= {`XLEN{1'b0}};
            end
        end
        else if (we && rd_addr != 5'b0) begin  // x0 is always 0
            regs[rd_addr] <= rd_data;
        end
    end
    
    // Asynchronous read
    //assign rs1_data = (rs1_addr == 5'b0) ? {`XLEN{1'b0}} : regs[rs1_addr];
    //assign rs2_data = (rs2_addr == 5'b0) ? {`XLEN{1'b0}} : regs[rs2_addr];


    assign rs1_data = (rs1_addr == 5'b0) ? {`XLEN{1'b0}} :
                  (we && (rd_addr != 5'b0) && (rd_addr == rs1_addr)) ? rd_data :
                  regs[rs1_addr];

    assign rs2_data = (rs2_addr == 5'b0) ? {`XLEN{1'b0}} :
                  (we && (rd_addr != 5'b0) && (rd_addr == rs2_addr)) ? rd_data :
                  regs[rs2_addr];

endmodule
