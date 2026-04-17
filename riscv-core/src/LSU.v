`include "macro.v"
module LSU (
    // Clock and Reset
    input clk,
    input rst,
    
    // Input from Execute Stage
    input ex_lsu_valid,
    output reg lsu_ex_ready,
    input [`XLEN-1:0] ex_lsu_addr,     // Memory address
    input [`XLEN-1:0] ex_lsu_data,     // Data to write
    input [1:0] ex_lsu_ctrl,           // 00: no action, 01: read, 10: write
    input [1:0] ex_lsu_size,        // 00: byte, 01: half-word, 10: word

    input ex_lsu_wb_data,
    input [4:0] ex_lsu_wb_rd,
    input ex_lsu_wb_wen,
    
    // Output to Write Back Unit
    output reg lsu_wbu_valid,
    input wbu_lsu_ready,
    output reg [`XLEN-1:0] lsu_wbu_data, // Data
    output reg [4:0] lsu_wbu_rd,        // Destination register
    output reg lsu_wbu_wen,             // Write enable for WBU

    // Memory Interface (AXI-lite)
    output reg mem_awvalid,
    input mem_awready,
    output reg [`XLEN-1:0] mem_awaddr,
    
    output reg mem_wvalid,
    input mem_wready,
    output reg [`XLEN-1:0] mem_wdata,
    output reg [3:0] mem_wstrb, // Write strobe for byte enables

    input mem_bvalid,
    output mem_bready,

    output reg mem_arvalid,
    input mem_arready,
    output reg [`XLEN-1:0] mem_araddr,

    input mem_rvalid,
    output mem_rready,
    input [`XLEN-1:0] mem_rdata,
    input mem_rlast
);
wire ex_lsu_handshaked = ex_lsu_valid && lsu_ex_ready;
wire mem_aw_handshaked = mem_awvalid && mem_awready;
wire mem_w_handshaked = mem_wvalid && mem_wready;
wire mem_b_handshaked = mem_bvalid && mem_bready;
wire mem_ar_handshaked = mem_arvalid && mem_arready;
wire mem_r_handshaked = mem_rvalid && mem_rready;
reg state, next_state; // 0: idle, 1: processing
localparam IDLE = 0, PROCESS = 1;

always @(posedge) begin
    if (rst) begin
        state <= 0;
    end
    else begin
        state <= next_state;
    end
end

always @(*) begin
    case (state)
        IDLE: begin
            if (ex_lsu_handshaked) begin
                if (ex_lsu_ctrl == 2'b00) begin // no action, directly pass through for write-back data
                    next_state = IDLE;
                end
                else if (ex_lsu_ctrl == 2'b01) begin // read operation
                    next_state = PROCESS;
                end
                else if (ex_lsu_ctrl == 2'b10) begin // write operation
                    next_state = PROCESS; 
                end
                else begin
                    next_state = IDLE;
                end
            end
            else begin
                next_state = IDLE;
            end
        end
        PROCESS: begin
            if (mem_b_handshaked || mem_r_handshaked) begin
                next_state = IDLE;
            end
        end
        default: begin
            next_state = IDLE;
        end
    endcase
end
assign mem_bready = state == PROCESS; // Always ready to accept write response
assign mem_rready = state == PROCESS; // Always ready to accept read data (for simplicity

always @(posedge clk) begin
    if (rst) begin
        mem_awvalid <= 0;
        mem_wvalid <= 0;
        mem_arvalid <= 0;
        lsu_ex_ready <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                lsu_ex_ready <= 1'b1; // Ready to accept new request
                mem_awvalid <= 0;
                mem_wvalid <= 0;
                mem_arvalid <= 0;
                if (ex_lsu_handshaked) begin
                    if (ex_lsu_ctrl == 2'b01) begin // read operation
                        mem_arvalid <= 1'b1;
                        mem_araddr <= ex_lsu_addr;
                        lsu_ex_ready <= 0; // Not ready to accept new request until current one is processed
                    end
                    else if (ex_lsu_ctrl == 2'b10) begin // write operation
                        mem_awvalid <= 1'b1;
                        mem_awaddr <= ex_lsu_addr;
                        mem_wvalid <= 1'b1;
                        mem_wdata <= ex_lsu_data;
                        lsu_ex_ready <= 0; // Not ready to accept new request until current one is processed
                        case (ex_lsu_size)
                            2'b00: mem_wstrb <= (4'b0001 << ex_lsu_addr[1:0]); // byte
                            2'b01: mem_wstrb <= (4'b0011 << ex_lsu_addr[1:0]); // half-word
                            2'b10: mem_wstrb <= 4'b1111; // word
                            default: mem_wstrb <= 4'b0000;
                        endcase
                    end
                end
            end
            PROCESS: begin
                lsu_ex_ready <= 0; // Not ready to accept new request until current one is processed
                if (mem_aw_handshaked) begin
                    mem_awvalid <= 0; // Deassert after handshake
                    mem_awaddr <= 0;
                end
                if (mem_w_handshaked) begin
                    mem_wvalid <= 0; // Deassert after handshake
                    mem_wdata <= 0;
                    mem_wstrb <= 0;
                end
                if (mem_ar_handshaked) begin
                    mem_arvalid <= 0; // Deassert after handshake
                    mem_araddr <= 0;
                end
                else if (mem_b_handshaked || mem_r_handshaked) begin
                    lsu_ex_ready <= 1'b1; // Ready for next request after current one is done
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        lsu_wbu_data <= `XLEN'b0;
        lsu_wbu_rd <= 5'b0;
        lsu_wbu_wen <= 1'b0;
        lsu_wbu_valid <= 1'b0;
    end
    else if (ex_lsu_handshaked && ex_lsu_ctrl == 2'b00) begin // directly pass through for write-back data
        lsu_wbu_data <= ex_lsu_wb_data;
        lsu_wbu_rd <= ex_lsu_wb_rd;
        lsu_wbu_wen <= ex_lsu_wb_wen;
        lsu_wbu_valid <= 1'b1;
    end
    else if (ex_lsu_handshaked && ex_lsu_ctrl == 2'b01) begin // read operation, wait for mem_rvalid
        lsu_wbu_data <= 0;
        lsu_wbu_rd <= ex_lsu_wb_rd;
        lsu_wbu_wen <= ex_lsu_wb_wen;
        lsu_wbu_valid <= 1'b0; // wait for mem_rvalid
    end
    else if (ex_lsu_handshaked && ex_lsu_ctrl == 2'b10) begin // write operation, wait for mem_bvalid
        lsu_wbu_data <= 0;
        lsu_wbu_rd <= 5'b0; // no destination register for write operation
        lsu_wbu_wen <= 1'b0; // no write-back for write operation
        lsu_wbu_valid <= 1'b0; // wait for mem_bvalid
    end
    else if (mem_r_handshaked) begin // read data is ready
        lsu_wbu_data <= mem_rdata;
        lsu_wbu_rd <= lsu_wbu_rd; // keep the same destination register
        lsu_wbu_wen <= lsu_wbu_wen;
        lsu_wbu_valid <= 1'b1; // data is ready for write-back
    end
    else if (mem_b_handshaked) begin // write data is ready
        lsu_wbu_data <= 0;
        lsu_wbu_rd <= 5'b0; // no destination register for write operation
        lsu_wbu_wen <= 1'b0; // no write-back for write operation
        lsu_wbu_valid <= 1'b1; // data is ready for write-back
    end
    else begin
        lsu_wbu_data <= 0;
        lsu_wbu_rd <= 5'b0;
        lsu_wbu_wen <= 1'b0;
        lsu_wbu_valid <= 1'b0;
    end
end
endmodule