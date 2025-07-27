// Single-cycle RV32I
module risc_v_sc (input logic clk, reset,
						// memory interfaces
						output logic[31:0] imem_addr,
						input logic[31:0] imem_read_data,
						
						output logic[31:0] dmem_addr,
						output logic dmem_write_en,
						output logic[31:0] dmem_write_data,
						input logic[31:0] dmem_read_data);
						
	logic[31:0] pc;
	logic[31:0] instruct;
	
	assign imem_addr = pc;
	assign instruct = imem_read_data;
	
	
	logic rf_we3;
	logic[4:0] rf_ra1, rf_ra2, rf_wa3;
	logic[31:0] rf_rd1, rf_rd2, rf_wd3;
	
	register_file #(.ADDR_W(5), .XLEN(32)) regfile(clk, rf_we3, rf_ra1, rf_ra2, rf_wa3, rf_wd3, rf_rd1, rf_rd2);
	
	logic [31:0] imm, imm_i_type, imm_s_type;
	assign imm_i_type = $signed(instruct[31:20]);
	assign imm_s_type = $signed({instruct[31:25], instruct[11:7]});
	
	// TODO
	// Need control signal to select imm to correct type's imm.
	assign imm = imm_i_type;
	
	// LW
	assign rf_ra1 = instruct[19:15];
	assign dmem_addr = imm + rf_rd1;
	assign rf_wa3 = instruct[11:7];
	assign rf_wd3 = dmem_read_data;
	// control path should set dmem_write_en=0, rf_we3=1, 
	
	// SW
	assign rf_ra2 = instruct[24:20];
	assign dmem_write_data = rf_rd2;
	// Control path should set dmem_write_en=1, rf_we3=0
	
	
	always_ff @(posedge clk) begin
		// Fetch instruction from pc
		
		// decode pc
		pc = pc + 32'h4;
	end
	
endmodule