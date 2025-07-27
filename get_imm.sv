`include "risc_v_def.svh"

module get_imm(output logic[31:0] ins);
	assign ins = `INSTR_OPCODE_LW;
endmodule