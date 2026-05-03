`include "macro.v"
/*
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
    //    else begin
    //     wb_rf_wen  <= 1'b0;
    //     wb_rf_rd   <= 5'b0;
    //     wb_rf_data <= `XLEN'b0;
    // end
end

endmodule*/

`include "macro.v"

module WBU (
    input clk,
    input rst,
    
    // From Memory stage
    input [`XLEN-1:0] lsu_wbu_data,
    input             lsu_wbu_valid,
    input [4:0]       lsu_wbu_rd,
    input             lsu_wbu_wen,
    input [`XLEN-1:0] lsu_wb_pc,
    input             ebreak_lsu_wbu,
    
    // Write back interface
    output [`XLEN-1:0] wb_rf_data,
    output [4:0]       wb_rf_rd,
    output             wb_rf_wen
);
import "DPI-C" function void npctrap(int commit_pc);
    assign wb_rf_data = lsu_wbu_data;
    assign wb_rf_rd   = lsu_wbu_rd;
    assign wb_rf_wen  = lsu_wbu_valid && lsu_wbu_wen;

    reg inst_cpmmit;
    reg [`XLEN-1:0] commit_pc;
    always @(posedge clk) begin
        if (rst) begin
            commit_pc <= 0;
            inst_cpmmit <= 0;
        end
        else begin
            inst_cpmmit <= lsu_wbu_valid;
            commit_pc <= lsu_wb_pc;
            if (ebreak_lsu_wbu) begin
                npctrap(lsu_wb_pc);
            end
        end
    end

function int read_pc();
	return commit_pc;
endfunction

export "DPI-C" function read_pc;

function int read_state();
	return {31'b0,inst_cpmmit};
endfunction

export "DPI-C" function read_state;

endmodule