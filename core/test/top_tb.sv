`timescale 1ns / 1ns
`include "macro.v"
module top_tb();
    reg clk;
    reg rst;

    top u_top (
    .clk(clk),
    .rst(rst)
    );

    always begin
        #5 clk = ~clk;
    end

    initial begin
        rst = 1;
        #20 rst = 0;

    end

    initial begin
        forever begin
            @(posedge clk)
            if (u_top.ebreak_flag==1) begin
                #30
                $finish;
            end
        end
    end

    initial begin
        $dumpfile("build/waveform.vcd");
        $dumpvars(0, LSU_tb);
    end
endmodule