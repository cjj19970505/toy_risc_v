`timescale 1ns / 1ps

module regfile_testbench();

	localparam int ADDR_W = 5;
	localparam int XLEN = 32;
	
	logic clk;
	logic we3;
	logic [ADDR_W-1:0] ra1, ra2, wa3;
	logic [XLEN-1:0] wd3;
	logic [XLEN-1:0] rd1, rd2;
	
	register_file #(.ADDR_W(ADDR_W), .XLEN(XLEN)) test_rf(clk, we3, ra1, ra2, wa3, wd3, rd1, rd2);
	
	always
	begin
		#5 clk <= ~clk;
	end
	
	initial
	begin
		clk <= 1'b1;
		we3 <= 0;
		
		ra1 <= 5'h3;
		ra2 <= 5'hc;
		wa3 <= 5'h0;
		
		wd3 <= 32'h0;
		
		for(int curr_addr=0; curr_addr<2**ADDR_W; curr_addr=curr_addr+1) begin
			#10 begin
				we3 <= 1;
				wa3 <= curr_addr;
				wd3 <= curr_addr * 2;
			end
		end
		
		#10 we3 <= 0;
		
		for(int curr_addr=0;curr_addr<2**ADDR_W;curr_addr=curr_addr+1) begin
			#10 begin
				ra1 <= curr_addr;
				ra2 <= curr_addr << 2;
			end
		end
		
		#10;
		ra1 <= 0;
		ra2 <= 0;
	end
	
endmodule
