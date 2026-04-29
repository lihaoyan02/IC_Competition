`include "macro.v"
module WBU (
    input clk,
    input rst,
    
    // From Memory stage
    input [`XLEN-1:0] lsu_wbu_data,        // Data from memory
    input lsu_wbu_valid,
    input [4:0] lsu_wbu_rd,               // Destination register
    input lsu_wbu_wen,                  // Write back enable
    
    // Write back interface
    output reg [`XLEN-1:0] wb_rf_data,    // Data to write
    output reg [4:0] wb_rf_rd,       // Destination register
    output reg wb_rf_wen         // Write back enable output
);

    always @(posedge clk) begin
        if (rst) begin
            wb_rf_data <= `XLEN'b0;
            wb_rf_rd <= 5'b0;
            wb_rf_wen <= 1'b0;
        end 
        else if (lsu_wbu_valid) begin
            wb_rf_wen <= lsu_wbu_wen;
            wb_rf_rd <= lsu_wbu_rd;
            wb_rf_data <= lsu_wbu_data;
        end
    end

endmodule