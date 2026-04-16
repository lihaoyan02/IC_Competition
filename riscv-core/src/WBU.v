module WBU (
    input clk,
    input rst_n,
    
    // From Memory stage
    input [31:0] mem_data,        // Data from memory
    input [31:0] alu_result,      // ALU result
    input [4:0] rd,               // Destination register
    input wb_en,                  // Write back enable
    input mem_to_reg,             // Select between memory data and ALU result
    
    // Write back interface
    output reg [31:0] wb_data,    // Data to write
    output reg [4:0] wb_rd,       // Destination register
    output reg wb_en_out          // Write back enable output
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_data <= 32'b0;
            wb_rd <= 5'b0;
            wb_en_out <= 1'b0;
        end else begin
            wb_en_out <= wb_en;
            wb_rd <= rd;
            // Select between memory data and ALU result
            wb_data <= mem_to_reg ? mem_data : alu_result;
        end
    end

endmodule