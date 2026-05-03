`include "macro.v"
module IMEM (
    input rst,
    input [`XLEN-1:0] if_imem_araddr,
    input imem_valid,
    output reg [`XLEN-1:0] imem_if_rdata,
    output reg imem_if_rvalid
);

`ifndef SV_TEST
import "DPI-C" function int pmem_read(int raddr);

    always @(*) begin
        if (imem_valid) begin
            imem_if_rdata = pmem_read(if_imem_araddr);  // Word-aligned addressing
            imem_if_rvalid = 1'b1;
        end else begin
            imem_if_rdata = 32'b0;
            imem_if_rvalid = 1'b0;
        end
    end
`else
    reg [`XLEN-1:0] mem [0:1023];  // 4KB instruction memory

    initial begin
        // for (int i = 0; i < 1024; i = i + 1) begin
        //     mem[i] = i+1;
        // end
        read_binary_file(`IMG_PATH);
    end

    task read_binary_file(string filename);
        integer fd, i, byte_val;
        reg [7:0] bytes [3:0];
        begin
            fd = $fopen(filename, "rb");
            if (fd == 0) begin
                $display("ERROR: Cannot open file %s", filename);
                $finish;
            end
            
            i = 0;
            while (!$feof(fd) && i < 1024) begin
                // Read 4 bytes (32-bit word)
                if ($fread(bytes, fd) > 0) begin
                    // Combine bytes in little-endian order
                    mem[i] = {bytes[3], bytes[2], bytes[1], bytes[0]};
                    i = i + 1;
                end else begin
                    break;
                end
            end
            
            $fclose(fd);
            $display("Loaded %0d words from %s", i, filename);
        end
    endtask

    always @(*) begin
        if (imem_valid) begin
            imem_if_rdata = mem[if_imem_araddr[11:2]];  // Word-aligned addressing
            imem_if_rvalid = 1'b1;
        end else begin
            imem_if_rdata = 32'b0;
            imem_if_rvalid = 1'b0;
        end
        
    end
`endif
endmodule