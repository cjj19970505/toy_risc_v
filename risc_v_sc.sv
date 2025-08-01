// Single-cycle RV32I

module RiscVControl(input logic[31:0] instruct,
								 output logic[2:0] instruct_type, // 0:R, 1:I,2:S,3:B,4:U,5:J, this can be used for 
							    output logic dmem_write_en,
								 output logic[1:0] dmem_read_size, // 0: byte, 1: half, 2: word
								 output logic[1:0] dmem_write_size, // 0: byte, 1: half, 2: word
								 output logic rf_we3,
								 output logic read_sign_extend);
					
	always_comb begin
		dmem_write_en = 0;
		instruct_type = 3'h0;
		dmem_read_size = 2'h0;
		dmem_write_size = 2'h0;
		rf_we3 = 0;
		read_sign_extend = 0;
		
		case(instruct[6:0]) // opcode
			7'b0000011: begin // For LB,LH,LW, LBU, LHU
				instruct_type = 3'h1; // I type
				dmem_write_en = 0;
				rf_we3 = 1;
				case(instruct[14:12])
					3'b000: begin // LB
						dmem_read_size = 2'h0;
						read_sign_extend = 1;
					end
					3'b001: begin // LH
						dmem_read_size = 2'h1;
						read_sign_extend = 1;
					end
					3'b010: begin // LW
						dmem_read_size = 2'h2;
					end
					3'b100: begin // LBU
						dmem_read_size = 2'h0;
						read_sign_extend = 0;
					end
					3'b101: begin // LHU
						dmem_read_size = 2'h1;
						read_sign_extend = 0;
					end
				endcase
			end
			7'b0100011: begin // For SB,SH,SW
				instruct_type = 3'h2; // S type
				dmem_write_en = 1;
				rf_we3 <= 0;
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
					input logic[1:0] instruct_type,
					output logic[31:0] imm); // 0:R, 1:I,2:S,3:B,4:U,5:J
	always_comb begin
		imm = 32'h0;
		case(instruct_type)
			1'h1: begin // I type
				imm <= $signed(instruct[31:20]);
			end
			2'h0: begin // S type
				imm <= $signed({instruct[31:25], instruct[11:7]});
			end
		endcase
	end
endmodule

module SingleCycleRiscV (input logic clk, reset,
						// memory interfaces
						output logic[31:0] imem_addr,
						input logic[31:0] imem_read_data,
						
						output logic[31:0] dmem_addr,
						output logic dmem_write_en,
						output logic[1:0] dmem_write_size,
						output logic[31:0] dmem_write_data,
						
						input logic[31:0] dmem_read_data);
						
	logic[31:0] pc;
	logic[31:0] instruct;
	
	assign imem_addr = pc;
	assign instruct = imem_read_data;
	
	
	logic rf_we3;
	logic[4:0] rf_ra1, rf_ra2, rf_wa3;
	logic[31:0] rf_rd1, rf_rd2, rf_wd3;
	
	RegisterFile #(.ADDR_W(5), .XLEN(32)) regfile(clk, rf_we3, rf_ra1, rf_ra2, rf_wa3, rf_wd3, rf_rd1, rf_rd2);
	
	logic[31:0] imm;
	logic[2:0] instruct_type;
	InstructionImm inst_imm(instruct, instruct_type, imm);
	
	logic sign_extend_en;
	logic[1:0] dmem_read_size; // dmem_write_size is defined in the parameters
	logic[31:0] sign_extended_dmem_read_data; // may not be signed extended
	SignExtend se_dmem_read(dmem_read_data, dmem_read_size, sign_extended_dmem_read_data);
	
	// LW
	assign rf_ra1 = instruct[19:15];
	assign dmem_addr = imm + rf_rd1;
	assign rf_wa3 = instruct[11:7];
	assign rf_wd3 = sign_extend_en ? sign_extended_dmem_read_data : dmem_read_data;
	
	// SW
	assign rf_ra2 = instruct[24:20];
	assign dmem_write_data = rf_rd2;
	
	RiscVControl control(instruct,
						 instruct_type, dmem_write_en, dmem_read_size, dmem_write_size, rf_we3, sign_extend_en);
	
	
	always_ff @(posedge clk) begin
		// Fetch instruction from pc
		
		// decode pc
		pc = pc + 32'h4;
	end
	
endmodule