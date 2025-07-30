`include "risc_v_def.svh"

module RegisterFile #( // calculate these once, up front
						parameter ADDR_W = 5,
						parameter XLEN = 32
					)
					(
						input logic clk,
						input logic we3,
						input logic [ADDR_W-1:0] ra1, ra2, wa3,
						input logic [XLEN-1:0] wd3,
						output logic [XLEN-1:0] rd1, rd2
					);
	logic [XLEN-1:0] rf[2**ADDR_W:0];
	always_ff @(posedge clk) begin
		if(we3) begin
			rf[wa3] <= wd3;
		end
	end
	assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
	assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule