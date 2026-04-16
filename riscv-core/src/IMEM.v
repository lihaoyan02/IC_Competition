`include "macro.v"
module IMEM (
    input rst,
    input [`XLEN-1:0] if_imem_araddr,
    input imem_valid,
    output reg [`XLEN-1:0] imem_if_rdata,
    output reg imem_if_rvalid
);

    reg [`XLEN-1:0] mem [0:1023];  // 4KB instruction memory

    initial begin
        for (int i = 0; i < 1024; i = i + 1) begin
            mem[i] = i;
        end
        // $readmemb("instruction.bin", mem);
    end

    always @(*) begin
        if (imem_valid) begin
            imem_if_rdata = mem[if_imem_araddr[11:2]];  // Word-aligned addressing
            imem_if_rvalid = 1'b1;
        end else begin
            imem_if_rdata = 32'b0;
            imem_if_rvalid = 1'b0;
        end
        
    end

endmodule