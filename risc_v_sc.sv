// Single-cycle RV32I

module RiscVControl(input logic[31:0] instruct,
								 output logic[2:0] instruct_type, // 0:R, 1:I,2:S,3:B,4:U,5:J, this can be used for 
							    output logic dmem_write_en,
								 output logic[1:0] dmem_read_size, // 0: byte, 1: half, 2: word
								 output logic[1:0] dmem_write_size, // 0: byte, 1: half, 2: word
								 output logic rf_we3,
								 output logic[2:0] alu_control,
								 
								 // specify which signal to write to register file.
								 output logic[1:0] signal_to_write,
								 output logic alu_op2_src,
								 output logic alu_op1_src);
					
	always_comb begin
		dmem_write_en = 0;
		instruct_type = 3'h0;
		dmem_read_size = 2'h0;
		dmem_write_size = 2'h0;
		rf_we3 = 0;
		
		alu_control = 0;
		signal_to_write = 0;
		alu_op2_src = 0; // default [rd]
		alu_op1_src = 0; // default imm
		
		case(instruct[6:0]) // opcode
			7'b0010111: begin // AUIPC
				instruct_type = 3'h4; // U type
				rf_we3 = 1;
				alu_control = 3'b010;
				alu_op2_src = 1; // from PC
				signal_to_write = 0; // Write ALU to register file.
			end
			7'b1101111: begin // JAL
				instruct_type = 3'h5; // J type
				rf_we3 = 1;
				alu_control = 3'b010;
				alu_op2_src = 1; // from PC
				signal_to_write = 3; // Jump mode, write [rd] with PC+4, write ALU to PC
			end
			7'b1100111: begin // JALR
				instruct_type = 3'h1; // I type
				rf_we3 = 1;
				alu_control = 3'b010;
				alu_op2_src = 0; // from [rs1]
				signal_to_write = 3; // Jump mode, write [rd] with PC+4, write ALU to PC
			end
			7'b0000011: begin // For LB,LH,LW, LBU, LHU
				instruct_type = 3'h1; // I type
				dmem_write_en = 0;
				rf_we3 = 1;
				alu_control = 3'b010;
				alu_op2_src = 0; // from [rs1]
				case(instruct[14:12])
					3'b000: begin // LB
						dmem_read_size = 2'h0;
						signal_to_write = 2; // Write signed extended mem
					end
					3'b001: begin // LH
						dmem_read_size = 2'h1;
						signal_to_write = 2; // Write signed extended mem
					end
					3'b010: begin // LW
						dmem_read_size = 2'h2;
						signal_to_write = 1; // Write unsigned mem
					end
					3'b100: begin // LBU
						dmem_read_size = 2'h0;
						signal_to_write = 1; // Write unsigned mem
					end
					3'b101: begin // LHU
						dmem_read_size = 2'h1;
						signal_to_write = 1; // Write unsigned mem
					end
				endcase
			end
			7'b0100011: begin // For SB,SH,SW
				instruct_type = 3'h2; // S type
				dmem_write_en = 1;
				rf_we3 = 0;
				alu_control = 3'b010;
				alu_op2_src = 0; // from [rs1]
				case(instruct[14:12])
					3'b000: begin // LB
						dmem_write_size = 2'h0;
					end
					3'b001: begin // LH
						dmem_write_size = 2'h1;
					end
					3'b010: begin // LW
						dmem_write_size = 2'h2;
					end
				endcase
			end
			7'b0010011: begin // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
				rf_we3 = 1;
				signal_to_write = 0; // ALU
				alu_op2_src = 0; // from [rs1]
				case(instruct[14:12])
					3'b000: begin // ADDI
						instruct_type = 3'h1; // I type
						alu_control = 3'b010; // sum
					end
				endcase
			end
			7'b0110011: begin
				instruct_type = 3'h0; // R type
				rf_we3 = 1;
				signal_to_write = 0; // Write ALU to [rd]
				alu_op2_src = 0; // from [rs1]
				alu_op1_src = 1; // from [rs2]
				case(instruct[14:12])
					3'b000: begin // ADD, SUB
						alu_control = {instruct[30], 2'b10};
					end
				endcase
			end
		endcase
	end			
endmodule

module SignExtend(input logic[31:0] in_word,
						 input logic[2:0] size_loged,
						 output logic[31:0] out_word);
	always_comb begin
		out_word = 'x;
		case(size_loged)
			3'd0: out_word = $signed(in_word[7:0]);
			3'd1: out_word = $signed(in_word[15:0]);
			3'd2: out_word = in_word;
		endcase
	end
endmodule

module InstructionImm(input logic[31:0] instruct,
					input logic[2:0] instruct_type,
					output logic[31:0] imm); // 0:R, 1:I,2:S,3:B,4:U,5:J
	always_comb begin
		imm = 32'h0;
		case(instruct_type)
			3'h1: begin // I type
				imm <= $signed(instruct[31:20]);
			end
			3'h2: begin // S type
				imm <= $signed({instruct[31:25], instruct[11:7]});
			end
			3'h4: begin // U type
				imm <= {instruct[31:12], 12'h0000};
			end
			3'h5: begin // J type
				imm <= $signed({instruct[31], instruct[19:12], instruct[20], instruct[30:25], instruct[24:21], 1'b0});
			end
		endcase
	end
endmodule

// 3'b000	AND (a & b)
// 3'b001	OR (a | b)
// 3'b010	Addition (a + b)
// 3'b110	Subtraction (a - b)
// 3'b111	Set Less Than (a < b)
module Alu(input logic[31:0] a,b,
			  input logic[2:0] alu_control,
			  output logic[31:0] result,
			  output logic zero);
	logic[31:0] condinvb, sum;
	assign condinvb = alu_control[2]? ~b : b;
	assign sum = a + condinvb + alu_control[2];
	
	always_comb begin
		case (alu_control[1:0])
			2'b00: result = a & b;
			2'b01: result = a | b;
			2'b10: result = sum;
			2'b11: result = sum[31];
		endcase
	end
endmodule


module SingleCycleRiscV #(parameter START_ADDR = 32'h80000000)
                   (input logic clk, reset,
							// memory interfaces
							output logic[31:0] imem_addr,
							input logic[31:0] imem_read_data,
							
							output logic[31:0] dmem_addr,
							output logic dmem_write_en,
							output logic[1:0] dmem_write_size,
							output logic[31:0] dmem_write_data,
							
							input logic[31:0] dmem_read_data,
							
							input logic[4:0] debug_reg_addr,
							output logic[31:0] debug_reg_read);
						
						
	logic[31:0] pc;
	logic[31:0] next_pc;
	
	logic[31:0] instruct;
	
	assign imem_addr = pc;
	assign instruct = imem_read_data;
	
	
	logic rf_we3;
	logic[4:0] rf_ra1, rf_ra2, rf_wa3;
	logic[31:0] rf_rd1, rf_rd2, rf_wd3;
	RegisterFile #(.ADDR_W(5), .XLEN(32)) regfile(clk, rf_we3, rf_ra1, rf_ra2, rf_wa3, rf_wd3, rf_rd1, rf_rd2, debug_reg_addr, debug_reg_read);
	
	logic[31:0] alu_op1, alu_op2;
	logic[2:0] alu_control;
	logic[31:0] alu_result;
	logic alu_zero;
	Alu alu(alu_op1, alu_op2, alu_control, alu_result, alu_zero);
	
	logic[31:0] imm;
	logic[2:0] instruct_type;
	InstructionImm inst_imm(instruct, instruct_type, imm);
	
	logic[1:0] dmem_read_size; // dmem_write_size is defined in the parameters
	logic[31:0] sign_extended_dmem_read_data; // may not be signed extended
	SignExtend se_dmem_read(dmem_read_data, dmem_read_size, sign_extended_dmem_read_data);
	
	// specify which signal to write to register file.
	// 0: alu_result, 1:sign_extend_en, 2:sign_extended_dmem_read_data, 3: pc+4 (jump mode, alu_result will be written to next_pc, rd will be wrtten with pc+4)
	logic[1:0] signal_to_write;
	
	// 0: imm, 1: [rs2]
	logic alu_op1_src;
	// 0: [rs1] rf_rd1; 1: pc
	logic alu_op2_src;
	
	// LW
	assign rf_ra1 = instruct[19:15];
	
	assign alu_op1 = (alu_op1_src == 0) ? imm : rf_rd2;
	assign alu_op2 = (alu_op2_src == 0) ? rf_rd1 : pc;
	// For LW, alu_control = 3'b010.
	assign dmem_addr = alu_result;
	
	assign rf_wa3 = instruct[11:7];
	
	logic[31:0] following_pc;
	assign following_pc = pc + 32'h4;
	
	assign rf_wd3 = (signal_to_write == 2'd0) ? alu_result :
						 (signal_to_write == 2'd1) ? dmem_read_data :
						 (signal_to_write == 2'd2) ? sign_extended_dmem_read_data :
						 (signal_to_write == 2'd3) ? following_pc : 0;
	
	// SW
	assign rf_ra2 = instruct[24:20];
	assign dmem_write_data = rf_rd2;
	
	assign next_pc = (signal_to_write == 2'd3) ? alu_result : following_pc;
	
	RiscVControl control(instruct,
						 instruct_type, dmem_write_en, dmem_read_size, dmem_write_size, rf_we3, alu_control, signal_to_write, alu_op2_src, alu_op1_src);
	
	
	always_ff @(posedge clk) begin
		if(reset) begin
			pc = START_ADDR;
		end else begin
			pc = next_pc;
		end
	end
	
endmodule