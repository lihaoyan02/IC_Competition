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

    input [`XLEN-1:0] ex_lsu_wb_data,
    input [4:0] ex_lsu_wb_rd,
    input ex_lsu_wb_wen,
    
    // Output to Write Back Unit
    output reg lsu_wbu_valid,
    output reg [`XLEN-1:0] lsu_wbu_data, // Data
    output reg [4:0] lsu_wbu_rd,        // Destination register
    output reg lsu_wbu_wen,             // Write enable for WBU

    // Data cache Interface
    output lsu_cache_valid,
    output lsu_cache_wen,
    output [`XLEN-1:0] lsu_cache_addr,
    output [`XLEN-1:0] lsu_cache_wdata,
    output [3:0] lsu_cache_wmask,
    output [1:0] lsu_cache_size,
    input [`XLEN-1:0] cache_lsu_rdata,
    input cache_lsu_hit
);

    // Internal state for pipeline
    reg lsu_state;  // 00: idle, 01: waiting for cache, 10: data ready
    localparam IDLE = 0, WAITING = 1;
    // Request buffer for cache misses
    reg [`XLEN-1:0] pending_addr;
    reg [`XLEN-1:0] pending_wdata;
    reg [`XLEN-1:0] wdata;
    reg [3:0] pending_wmask, wmask;
    reg [1:0] pending_size;
    reg [4:0] pending_rd;
    reg pending_cache_wen;
    reg [`XLEN-1:0] wb_data; // Data to write back to WBU
    wire cache_wen = ex_lsu_valid ? (ex_lsu_ctrl == 2'b10) : 1'b0; // Write enable for cache
    
    // Connect cache interface
    assign lsu_cache_valid = (lsu_state == WAITING) || (ex_lsu_valid && (ex_lsu_ctrl != 2'b00));
    assign lsu_ex_ready = (lsu_state == IDLE && ex_lsu_valid && (ex_lsu_ctrl == 2'b00)) || 
        (lsu_state == IDLE && ex_lsu_valid && (ex_lsu_ctrl != 2'b00) && cache_lsu_hit) ||
        (lsu_state == WAITING && cache_lsu_hit);
    assign lsu_cache_addr = (lsu_state == WAITING) ? pending_addr : ex_lsu_addr;
    assign lsu_cache_wdata = (lsu_state == WAITING) ? pending_wdata : wdata;
    assign lsu_cache_wmask = (lsu_state == WAITING) ? pending_wmask : wmask;
    assign lsu_cache_wen = (lsu_state == WAITING) ? pending_cache_wen : cache_wen; // Write enable for cache
    assign lsu_cache_size = (lsu_state == WAITING) ? pending_size : ex_lsu_size;
    
    always @(posedge clk) begin
        if (rst) begin
            lsu_state <= IDLE;
            lsu_wbu_valid <= 1'b0;
            lsu_wbu_data <= 32'h0;
            lsu_wbu_rd <= 5'h0;
            lsu_wbu_wen <= 1'b0;

            pending_addr <= 32'h0;
            pending_wdata <= 32'h0;
            pending_wmask <= 4'b0000;
            pending_size <= 2'b00;
            pending_rd <= 5'h0;
            pending_cache_wen <= 1'b0;
        end else begin
            lsu_wbu_valid <= 1'b0; 
            lsu_wbu_data <= 32'h0;
            lsu_wbu_rd <= 5'h0;
            lsu_wbu_wen <= 1'b0;
            case (lsu_state)
                IDLE: begin  // IDLE - Ready to accept requests                 
                    if (ex_lsu_valid && (ex_lsu_ctrl != 2'b00)) begin
                        // Check cache hit/miss
                        if (cache_lsu_hit) begin
                            // Cache hit - return data immediately
                            lsu_wbu_valid <= 1'b1;
                            lsu_wbu_data <= wb_data;
                            lsu_wbu_rd <= ex_lsu_wb_rd;
                            lsu_wbu_wen <= ex_lsu_wb_wen;
                            lsu_state <= IDLE;  // Stay in idle for next request
                        end else begin
                            // Cache miss - stall pipeline and save request
                            lsu_wbu_valid <= 1'b0; // Don't send data to WBU yet
                            pending_cache_wen <= cache_wen;
                            pending_addr <= ex_lsu_addr;
                            pending_wdata <= wdata;
                            pending_wmask <= wmask;
                            pending_size <= ex_lsu_size;
                            pending_rd <= ex_lsu_wb_rd;
                            lsu_state <= WAITING;  // Move to waiting state
                        end
                    end 
                    else if(ex_lsu_valid) begin // No memory operation, just pass through for write-back
                        lsu_wbu_valid <= 1'b1;
                        lsu_wbu_data <= wb_data;
                        lsu_wbu_rd <= ex_lsu_wb_rd;
                        lsu_wbu_wen <= ex_lsu_wb_wen;
                        lsu_state <= IDLE;
                    end
                    else begin
                        lsu_wbu_valid <= 1'b0;
                        lsu_state <= IDLE; // Stay in idle if no valid request
                    end
                end
                WAITING: begin  // WAITING - Waiting for cache miss data
                    // Check if cache hit now (data fetched from memory)
                    if (cache_lsu_hit) begin
                        // Cache hit - data is ready
                        lsu_wbu_valid <= 1'b1;
                        lsu_wbu_data <= wb_data;
                        lsu_wbu_rd <= pending_rd;
                        lsu_wbu_wen <= ~pending_cache_wen;
                        lsu_state <= IDLE;  // Move to data ready state

                        pending_cache_wen <= 1'b0; // Clear pending write enable
                        pending_addr <= 32'h0; // Clear pending address
                        pending_wdata <= 32'h0; // Clear pending data
                        pending_wmask <= 4'b0000; // Clear pending write mask
                        pending_size <= 2'b00; // Clear pending size
                        pending_rd <= 5'h0; // Clear pending destination register
                    end else begin
                        // Still waiting
                        lsu_state <= WAITING;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        wmask = 4'b0000; // Default to no write
        wdata = ex_lsu_data; // Default to input data
        if (ex_lsu_valid) begin
            if (ex_lsu_ctrl==2'b10) begin
                case (ex_lsu_size)
                    2'b00: begin
                        wmask = (4'b0001 << ex_lsu_addr[1:0]); // Byte
                        wdata = ex_lsu_data << (ex_lsu_addr[1:0] * 8); // Shift data to correct byte position
                    end
                    2'b01: begin
                        wmask = (4'b0011 << ex_lsu_addr[1:0]); // Half-word
                        wdata = ex_lsu_data << (ex_lsu_addr[1:0] * 8); // Shift data to correct half-word position
                    end
                    2'b10: begin
                        wmask = 4'b1111; // Word
                        wdata = ex_lsu_data;
                    end
                    default: begin
                        wmask = 4'b0000; // No write
                        wdata = ex_lsu_data;
                    end
                endcase
            end
        end
    end

    always @(*) begin
        wb_data = ex_lsu_wb_data; // Default to ALU result for write-back
        if (cache_lsu_hit & !lsu_cache_wen) begin
            if (lsu_state == IDLE) begin
                case (ex_lsu_size)
                2'b00: wb_data = {{24{cache_lsu_rdata[7]}}, cache_lsu_rdata[7:0]}; // Byte
                2'b01: wb_data = {{16{cache_lsu_rdata[15]}}, cache_lsu_rdata[15:0]}; // Half-word
                2'b10: wb_data = cache_lsu_rdata;// Word
                default: $finish;
                endcase
            end
            else if (lsu_state == WAITING) begin
                case (pending_size)
                2'b00: wb_data = {{24{cache_lsu_rdata[7]}}, cache_lsu_rdata[7:0]}; // Byte
                2'b01: wb_data = {{16{cache_lsu_rdata[15]}}, cache_lsu_rdata[15:0]}; // Half-word
                2'b10: wb_data = cache_lsu_rdata;// Word
                default: $finish;
                endcase
            end
        end
    end
endmodule