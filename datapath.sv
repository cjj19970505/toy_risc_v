module datapath(input logic clk, reset,
					 output logic clk_o);
	assign clk_o = clk & reset;
	
endmodule