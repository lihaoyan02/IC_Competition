`include "macro.v"

module L1_cache (
    input clk,
    input rst,
    
    // Cache request interface
    input valid,                       // Valid signal for memory operation
    input wen,                         // Write enable
    input [`XLEN-1:0] addr,           // Address
    input [`XLEN-1:0] wdata,          // Data to write
    input [3:0] wmask,                // Write mask
    input [1:0] size,                 // 00: byte, 01: half-word, 10: word
    
    // Cache response interface
    output reg [`XLEN-1:0] rdata,    // Data read from cache (combinational)
    output wire hit                    // Cache hit signal (registered)
);

    // Simple memory for testing - stores incrementing values based on address
    parameter MEM_SIZE = 1024;        // 1K memory locations
    reg [31:0] memory [MEM_SIZE-1:0];
    
    // LFSR for random hit generation
    reg [31:0] lfsr;
    wire lfsr_out;
    
    // Hit rate control: LFSR_HIT_THRESHOLD determines hit probability
    // Higher values = higher hit rate. Range: 0-32
    localparam LFSR_HIT_THRESHOLD = 20;  // ~62.5% hit rate
    
    integer i;
    // Initialize memory with values equal to the address (incrementing)
    initial begin
        // for (i = 0; i < MEM_SIZE; i = i + 1) begin
        //     memory[i] = i;  // Each address contains its own address as value
        // end
        read_binary_file(`IMG_PATH);
        lfsr = 32'hACE1;  // Non-zero seed for LFSR
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
                    memory[i] = {bytes[3], bytes[2], bytes[1], bytes[0]};
                    i = i + 1;
                end else begin
                    break;
                end
            end
            
            $fclose(fd);
            $display("Loaded %0d words from %s", i, filename);
        end
    endtask
    
    // LFSR (Linear Feedback Shift Register) for random number generation
    // Using Fibonacci LFSR with taps at bits 31, 30, 28, 26
    assign lfsr_out = lfsr[31] ^ lfsr[30] ^ lfsr[28] ^ lfsr[26];
    
    // Determine hit based on LFSR - MSBs give better randomness
    wire cache_hit = (lfsr[31:26] < LFSR_HIT_THRESHOLD);
    assign hit = cache_hit & valid;  // Hit is only valid when there's a valid request
    
    // Memory address (lower bits of address, masked to MEM_SIZE)
    wire [11:0] mem_addr = addr[11:0];
    
    // Combinational read data path (like Regfile)
    // Return memory data directly when valid and read operation
    always @(*) begin
        case (size)
            2'b00: rdata = memory[mem_addr[11:2]] >> (mem_addr[1:0] * 8); // Byte
            2'b01: rdata = memory[mem_addr[11:2]] >> (mem_addr[1] * 16); // Half-word
            2'b10: rdata = memory[mem_addr[11:2]]; // Word
            default: rdata = memory[mem_addr[11:2]];
        endcase
    end
    
    // Synchronous hit signal for pipeline control
    always @(posedge clk) begin
        if (rst) begin
            lfsr <= 32'hACE1;
        end else begin
            // Update LFSR on every cycle for continuous randomness
            lfsr <= {lfsr[30:0], lfsr_out};
            if (hit & wen) begin
                // Write hit - update memory with write mask
                if (wmask[0]) memory[mem_addr[11:2]][7:0]   <= wdata[7:0];
                if (wmask[1]) memory[mem_addr[11:2]][15:8]  <= wdata[15:8];
                if (wmask[2]) memory[mem_addr[11:2]][23:16] <= wdata[23:16];
                if (wmask[3]) memory[mem_addr[11:2]][31:24] <= wdata[31:24];
            end
        end
    end

endmodule
