`timescale 1ns / 1ps
`include "macro.v"
`define CLK_PERIOD 4
module tb_WBU(

    );
    reg clk;
    reg rst;
    
    reg [`XLEN-1:0] mem_data;
    reg [`XLEN-1:0] alu_result;
    reg [4:0] rd;
    reg mem_to_reg;
    reg wb_en;
    
    wire [`XLEN-1:0] wb_data;
    wire [4:0] wb_rd;
    wire wb_en_out;
    
    
    WBU u_WBU(
        .clk            (clk        ),
        .rst            (rst        ),
        .mem_data       (mem_data   ),
        .alu_result     (alu_result ),
        .rd             (rd         ),
        .wb_en          (wb_en      ),
        .mem_to_reg     (mem_to_reg ),
        .wb_data        (wb_data    ),
        .wb_rd          (wb_rd      ),
        .wb_en_out      (wb_en_out  )
    );
    
    initial begin
        clk = 0;
        rst = 1;
        mem_data = 0;
        alu_result = 0;
        rd = 0;
        wb_en = 0;
        mem_to_reg = 0;
        # 5 rst = 0;
        #(`CLK_PERIOD * 5) rst = 1;
        #(`CLK_PERIOD * 2) $stop;
    end
    
    always #(`CLK_PERIOD / 2) begin
        clk <= ~clk;
    end
    
    // Let mem_to_reg switch between 0 and 1
    always @(posedge clk) begin
        if(rst)
            mem_to_reg <= 0;
        else
            mem_to_reg <= mem_to_reg + 1;
    end
    
    always @(posedge clk) begin
        if(rst) begin
            mem_data <= 0;
            alu_result <= 0;
            rd <= 0;
        end
        else begin
            mem_data <= $random ;   //32-bit
            alu_result <= $random;  //32-bit
            rd  <= $random % 32;    //5-bit
            wb_en <= $random % 2;   //1-bit
        end
    end
    
endmodule
