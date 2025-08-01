`timescale 1ns / 1ps

module DummyMemory #( // calculate these once, up front
							parameter SIZE = 8192,
							parameter START_ADDR = 32'h80000000
					   )(
							input logic clk,
							input logic[31:0] addr,
							input logic[31:0] ro_addr2, // Just used for fetch instruction since we now modeling the CPU in a simple way.
							input logic we,
							input logic[1:0] write_size, // 0:byte, 1:half word, 2:word
							input logic[31:0] wd,
							output logic[31:0] rd,
							output logic[31:0] rd2,
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
	
	logic[ADDR_WIDTH-1:0] inner_addr2;
	logic[ADDR_WIDTH-3:0] word_index2;
	logic[1:0] in_word_index2;
	assign inner_addr2	= ro_addr2 - START_ADDR;
	assign word_index2 = inner_addr2[ADDR_WIDTH-1:2];
	assign in_word_index2 = inner_addr2[1:0];
	assign rd2 = inner_mem[word_index2] >> ({31'b0, in_word_index2} << 3); // If addr is 4-byte align, all 4 bytes in rd is valid, 2->2, 1->1
	
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
	localparam int unsigned MAX_ELF_FILE_BYTES = 1024 * 1024;
	localparam int unsigned DUMMY_MEM_SIZE = 8192;
	localparam int unsigned DUMMY_START_ADDRESS = 32'h80000000;
	localparam int unsigned ELF_FILE_OFFSET = 32'h1000;
	
	logic clk;
	
	logic[31:0] loader_mem_addr;
	logic[31:0] loader_mem_ro_addr2;
	logic loader_mem_we;
	logic[1:0] loader_mem_write_size;
	logic[31:0] loader_mem_wd;
	
	logic[31:0] cpu_mem_addr;
	logic[31:0] cpu_mem_ro_addr2;
	logic cpu_mem_we;
	logic[1:0] cpu_mem_write_size;
	logic[31:0] cpu_mem_wd;
	
	logic loader_or_cpu; // 0 for loader, 1 for cpu
	
	logic[31:0] mem_addr;
	logic[31:0] mem_ro_addr2;
	logic mem_we;
	logic[1:0] mem_write_size;
	logic[31:0] mem_wd;
	
	assign mem_addr = loader_or_cpu ? cpu_mem_addr : loader_mem_addr;
	assign mem_ro_addr2 = loader_or_cpu ? cpu_mem_ro_addr2 : loader_mem_ro_addr2;
	assign mem_we = loader_or_cpu ? cpu_mem_we : loader_mem_we;
	assign mem_write_size = loader_or_cpu ? cpu_mem_write_size : loader_mem_write_size;
	assign mem_wd = loader_or_cpu ? cpu_mem_wd : loader_mem_wd;
	
	
	logic[31:0] mem_rd;
	logic[31:0] mem_rd2;
	
	logic[1:0] debug_byte_index;
	logic[31:0] debug_read_word;
	
	DummyMemory #(.SIZE(DUMMY_MEM_SIZE), .START_ADDR(DUMMY_START_ADDRESS)) dummy_mem(clk, mem_addr, mem_ro_addr2, mem_we, mem_write_size, mem_wd, mem_rd, mem_rd2, debug_byte_index, debug_read_word);
	
	
	// logic cpu_reset;
	
	// SingleCycleRiscV cpu(clk, cpu_reset, loader_mem_ro_addr2, mem_rd2, mem_addr, loader_mem_we, loader_mem_write_size, loader_mem_wd, mem_rd);
	
	
	// load initial memory
	int fd = 0;
	int ch = -1;
	logic[32:0] curr_addr = 32'h80000000;
	logic[32:0] curr_offset = 0;
	logic[32:0] actual_file_size = 0;
	
	int unsigned elf_file_size = 0;
	logic [7:0] elf_file_mem [0:MAX_ELF_FILE_BYTES-1];
	
	initial begin
		loader_or_cpu = 0;
		clk = 1;
		fd = $fopen("data.elf", "rb");
		if(fd==0) begin
			$fatal(1, "Can't open elf file.");
		end
		elf_file_size = $fread(elf_file_mem, fd);
		$fclose(fd);
		fd = 0;
		$display("elf file size: %d", elf_file_size);
		loader_mem_we = 1;
		loader_mem_write_size = 0;
		$display("Writing program into dummy memory ");
		$display("Loop count: %d", (elf_file_size - ELF_FILE_OFFSET) < DUMMY_MEM_SIZE ? (elf_file_size - ELF_FILE_OFFSET) : DUMMY_MEM_SIZE);
		for(int unsigned i = 0; i < ((elf_file_size - ELF_FILE_OFFSET) < DUMMY_MEM_SIZE ? (elf_file_size - ELF_FILE_OFFSET) : DUMMY_MEM_SIZE); i=i+1) begin
			#1 clk = 0;
			loader_mem_addr = DUMMY_START_ADDRESS + i;
			loader_mem_ro_addr2 = DUMMY_START_ADDRESS + i;
			loader_mem_wd = elf_file_mem[ELF_FILE_OFFSET + i];
			#1 clk = 1;
			#1;
			assert(mem_rd[7:0] == elf_file_mem[ELF_FILE_OFFSET + i]) else begin
				$display("Write Test, Error: {0x%08X:0x%02X} is stored, file {0x%08X:0x%02X}", mem_addr, mem_rd[7:0], ELF_FILE_OFFSET + i, elf_file_mem[ELF_FILE_OFFSET + i]);
				$stop(2);
			end
			assert(mem_rd2[7:0] == elf_file_mem[ELF_FILE_OFFSET + i]) else begin
				$display("Write Test mem_ro_addr2, Error: {0x%08X:0x%02X} is stored, file {0x%08X:0x%02X}", mem_ro_addr2, mem_rd2[7:0], ELF_FILE_OFFSET + i, elf_file_mem[ELF_FILE_OFFSET + i]);
				$stop(2);
			end
		end
		$display("Write test pass.");
		
		loader_mem_we = 0;
		for(int unsigned i = 0; i < ((elf_file_size - ELF_FILE_OFFSET) < DUMMY_MEM_SIZE ? (elf_file_size - ELF_FILE_OFFSET) : DUMMY_MEM_SIZE); i=i+1) begin
			loader_mem_addr = DUMMY_START_ADDRESS + i;
			#1 assert(mem_rd[7:0] == elf_file_mem[ELF_FILE_OFFSET + i]) else begin
				$display("Read Test Error: {0x%08X:0x%02X} is stored, file {0x%08X:0x%02X}", mem_addr, mem_rd[7:0], ELF_FILE_OFFSET + i, elf_file_mem[ELF_FILE_OFFSET + i]);
				$stop(2);
			end
		end
		for(int unsigned i = 0; i < ((elf_file_size - ELF_FILE_OFFSET) < DUMMY_MEM_SIZE ? (elf_file_size - ELF_FILE_OFFSET) : DUMMY_MEM_SIZE); i=i+1) begin
			loader_mem_ro_addr2 = DUMMY_START_ADDRESS + i;
			#1 assert(mem_rd2[7:0] == elf_file_mem[ELF_FILE_OFFSET + i]) else begin
				$display("Read Test mem_ro_addr2, Error: {0x%08X:0x%02X} is stored, file {0x%08X:0x%02X}", mem_ro_addr2, mem_rd2[7:0], ELF_FILE_OFFSET + i, elf_file_mem[ELF_FILE_OFFSET + i]);
				$stop(2);
			end
		end
		$display("Read test pass.");
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



