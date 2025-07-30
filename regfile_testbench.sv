`timescale 1ns / 1ps

module DummyMemory #( // calculate these once, up front
							parameter SIZE = 8192,
							parameter START_ADDR = 32'h80000000
					   )(
							input logic clk,
							input logic[31:0] addr,
							input logic we,
							input logic[1:0] write_size, // 0:byte, 1:half word, 2:word
							input logic[31:0] wd,
							output logic[31:0] rd,
							output logic[1:0] debug_byte_index,
							output logic[31:0] debug_read_word
						);
	
	
	localparam ADDR_WIDTH = $clog2(SIZE);
	
	logic[31:0] inner_mem[(SIZE >> 2)-1:0];
	logic[ADDR_WIDTH-1:0] inner_addr;
	logic[ADDR_WIDTH-3:0] word_index;
	logic[1:0] in_word_index;
	
	assign debug_byte_index = in_word_index;
	assign debug_read_word = inner_mem[word_index];
	
   assign inner_addr	= addr - START_ADDR;
	assign word_index = inner_addr[ADDR_WIDTH-1:2];
	assign in_word_index = inner_addr[1:0];
	assign rd = inner_mem[word_index] >> ({31'b0, in_word_index} << 3); // If addr is 4-byte align, all 4 bytes in rd is valid, 2->2, 1->1
	
	always_ff @(posedge clk) begin
		if(we) begin
			case(write_size)
				2'h0: begin
					inner_mem[word_index][({31'b0, in_word_index} << 3) +: 8] = wd[8-1:0];
				end
				2'h1: begin
					inner_mem[word_index][({31'b0, in_word_index} << 3) +: 16] = wd[16-1:0];
				end
				2'h2: begin
					inner_mem[word_index][({31'b0, in_word_index} << 3) +: 32] = wd[32-1:0];
				end
			endcase
		end
	end
endmodule

module main_testbench();
	
	logic clk;
	logic[31:0] mem_addr;
	logic mem_we;
	logic[1:0] mem_write_size;
	logic[31:0] mem_wd;
	logic[31:0] mem_rd;
	
	logic[1:0] debug_byte_index;
	logic[31:0] debug_read_word;
	
	DummyMemory #(.SIZE(8192), .START_ADDR(32'h80000000)) dummy_mem(clk, mem_addr, mem_we, mem_write_size, mem_wd, mem_rd, debug_byte_index, debug_read_word);
	
	// load initial memory
	int fd = 0;
	int ch = -1;
	logic[32:0] curr_addr = 32'h80000000;
	logic[32:0] file_offset = 32'h1000;
	logic[32:0] file_read_size = 8192;
	logic[32:0] curr_offset = 0;
	logic[32:0] actual_file_size = 0;
	initial begin
		clk = 1;
		fd = $fopen("data.elf", "rb");
		if(fd==0) begin
			$fatal(1, "Can't open elf file.");
		end
		
		mem_we = 1;
		mem_write_size = 0;
		
		do begin
			ch = $fgetc(fd);
			if(ch != -1 && curr_offset >= file_offset && curr_offset < file_offset + file_read_size) begin
				#5 clk = ~clk; // 1->0, prepare data in clk low
				
				mem_addr = curr_addr;
				curr_addr = curr_addr + 1;
				actual_file_size = actual_file_size + 1;
				mem_wd = ch;
				#5 clk = ~clk; // 0->1, flush into mem
				#1 assert(mem_rd[7:0] == ch[7:0]);
				$display("Load 0x%02X from file in 0x%08X, supposed to be 0x%02X", mem_rd[7:0], mem_addr, ch[7:0]);
			end
			curr_offset = curr_offset + 1;
		end while (ch != -1);
		
		mem_we = 0;
		for(int curr_byte_index=0; curr_byte_index<actual_file_size; curr_byte_index=curr_byte_index+1) begin
			begin
				#1 mem_addr = 32'h80000000 + curr_byte_index;
				#1 $display("0x%08X: 0x%02X", mem_addr, mem_rd[7:0]);
			end
		end
		
		$stop(2);
	end
	
endmodule

module regfile_testbench();
	localparam int ADDR_W = 5;
	localparam int XLEN = 32;
	
	logic clk;
	logic we3;
	logic [ADDR_W-1:0] ra1, ra2, wa3;
	logic [XLEN-1:0] wd3;
	logic [XLEN-1:0] rd1, rd2;
	
	RegisterFile #(.ADDR_W(ADDR_W), .XLEN(XLEN)) test_rf(clk, we3, ra1, ra2, wa3, wd3, rd1, rd2);
	
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
				we3 = 1;
				wa3 = curr_addr;
				wd3 = curr_addr * 2;
			end
		end
		
		#10 we3 <= 0;
		
		for(int curr_addr=0;curr_addr<2**ADDR_W;curr_addr=curr_addr+1) begin
			#9 begin
				ra1 = curr_addr;
				ra2 = curr_addr << 2;
			end
			# 1 begin
				$display("ra1=%h ra2=%h rd1=%h rd2=%h", ra1, ra2, rd1, rd2);
				assert(rd1 == ra1 * 2) else $fatal(1, "Something's wrong1");
				assert(rd2 == ra2 * 2) else $fatal(1, "Something's wrong2");
			end
		end
		
		#10;
		ra1 <= 0;
		ra2 <= 0;
		
		$stop(2);
	end
endmodule



