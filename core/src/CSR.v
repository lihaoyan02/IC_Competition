`include "macro.v"
module CSR #(CSR_NUM = 4) (
	input clk,
	input rst,
	input csr_wen,
	input [`XLEN-1:0] pc,
	input csr_event,
	input [`CSR_ADDR_WIDTH-1:0] csr_raddr,
    input [`CSR_ADDR_WIDTH-1:0] csr_waddr,
	input [`XLEN-1:0] csr_wdata,
	output reg [`XLEN-1:0] csr_rdata
);

reg [`XLEN-1:0] csr [CSR_NUM-1:0];
integer i = 0;

import "DPI-C" function void unknow_inst();

always @(posedge clk) begin
	if(rst) begin
		csr[0] <= 32'h1800; //mestatus machine mode
		for (i=1; i<CSR_NUM; i = i+1) begin
			csr[i] <= {`XLEN{1'b0}};
		end
	end
	else begin
		if(csr_event) begin
			csr[2] <= pc;
            if (csr[0]==32'h1800) begin
                csr[3] <= 32'hb;
            end
			else begin
                unknow_inst();
            end
		end
        else if(csr_wen) begin
			case (csr_waddr)
				12'h300: //mestatus
					csr[0] <= csr_wdata; 
				12'h305: //mtvec
					csr[1] <= csr_wdata; 
				12'h341: //mepc
					csr[2] <= csr_wdata;
				12'h342: //mecause
					csr[3] <= csr_wdata;
				default: unknow_inst();
			endcase
		end
	end
end


always @(*) begin
	case (csr_raddr)
		12'h300:
			csr_rdata = csr[0];
		12'h305:
			csr_rdata = csr[1];
		12'h341:
			csr_rdata = csr[2];
		12'h342:
			csr_rdata = csr[3];
		default:
			csr_rdata = 32'b0;
	endcase
end

endmodule