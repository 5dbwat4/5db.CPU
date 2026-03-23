`include "core_struct.vh"
`include "csr_struct.vh"

module controller (
    input CorePack::inst_t inst,
    output logic we_reg,
    output logic we_mem,
    output logic re_mem,
    output logic npc_sel,
    output CorePack::imm_op_enum immgen_op,
    output CorePack::alu_op_enum alu_op,
    output CorePack::cmp_op_enum cmp_op,
    output CorePack::alu_asel_op_enum alu_asel,
    output CorePack::alu_bsel_op_enum alu_bsel,
    output CorePack::wb_sel_op_enum wb_sel,
    output CorePack::mem_op_enum mem_op,

    // CSR specific outputs
    output logic we_csr,
    output logic [1:0] csr_ret,
    output CsrPack::csr_alu_op_enmu csr_alu_op,
    output CsrPack::csr_alu_asel_op_enum csr_alu_asel,
    output CsrPack::csr_alu_bsel_op_enum csr_alu_bsel
);

import CorePack::*;
import CsrPack::*;

logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;
logic [4:0] rs1;

assign opcode = inst[6:0];
assign funct3 = inst[14:12];
assign funct7 = inst[31:25];
assign rs1    = inst[19:15];

wire is_lui    = (opcode == LUI_OPCODE);
wire is_auipc  = (opcode == AUIPC_OPCODE);
wire is_jal    = (opcode == JAL_OPCODE);
wire is_jalr   = (opcode == JALR_OPCODE);
wire is_branch = (opcode == BRANCH_OPCODE);
wire is_load   = (opcode == LOAD_OPCODE);
wire is_store  = (opcode == STORE_OPCODE);
wire is_imm    = (opcode == IMM_OPCODE);
wire is_immw   = (opcode == IMMW_OPCODE);
wire is_reg    = (opcode == REG_OPCODE);
wire is_regw   = (opcode == REGW_OPCODE);

wire is_csr = (opcode == CSR_OPCODE);

wire is_system = (opcode == 7'b1110011); // same as CSR_OPCODE
wire is_csrrw  = is_system && (funct3 == CSRRW_FUNCT3);
wire is_csrrs  = is_system && (funct3 == CSRRS_FUNCT3);
wire is_csrrc  = is_system && (funct3 == CSRRC_FUNCT3);
wire is_csrrwi = is_system && (funct3 == CSRRWI_FUNCT3);
wire is_csrrsi = is_system && (funct3 == CSRRSI_FUNCT3);
wire is_csrrci = is_system && (funct3 == CSRRCI_FUNCT3);

wire is_ecall  = is_system && (inst == ECALL);
wire is_ebreak = is_system && (inst == EBREAK);
wire is_mret   = is_system && (inst == MRET);
wire is_sret   = is_system && (inst == SRET);

wire is_csr_inst = is_csrrw | is_csrrs | is_csrrc | is_csrrwi | is_csrrsi | is_csrrci;

// For CSR instructions:
// we_csr is 1 for CSR instructions except when (rs1 == 0 and operation is RS or RC) 
// wait, csrrw ALWAYS writes (even if rs1 == 0). csrrs/c don't write if rs1 == 0.
assign we_csr = is_csrrw | is_csrrwi |
                ((is_csrrs | is_csrrc | is_csrrsi | is_csrrci) && (rs1 != 5'b0));

assign csr_ret[1] = is_mret;
assign csr_ret[0] = is_sret;

assign we_reg = is_lui | is_auipc | is_jal | is_jalr | is_load | is_imm | is_immw | is_reg | is_regw | is_csr_inst;
assign we_mem = is_store;
assign re_mem = is_load;
assign npc_sel = is_jal | is_jalr | is_branch;

always_comb begin
    if (is_load || is_jalr || is_imm || is_immw) begin
        immgen_op = I_IMM;
    end else if (is_store) begin
        immgen_op = S_IMM;
    end else if (is_branch) begin
        immgen_op = B_IMM;
    end else if (is_auipc || is_lui) begin
        immgen_op = U_IMM;
    end else if (is_jal) begin
        immgen_op = UJ_IMM;
    end else if (is_csrrwi || is_csrrsi || is_csrrci) begin
        immgen_op = CSR_IMM; // wait, is CSR_IMM defined? Let's check. Yes, in CorePack.
    end else begin
        immgen_op = IMM0;
    end
end

always_comb begin
    alu_asel = ASEL_REG;
    if (is_auipc || is_jal || is_branch) begin
        alu_asel = ASEL_PC;
    end else if (is_lui) begin
        alu_asel = ASEL0;
    end
end

always_comb begin
    alu_bsel = BSEL_REG;
    if (is_lui || is_auipc || is_jal || is_jalr || is_load || is_store || is_imm || is_immw) begin
        alu_bsel = BSEL_IMM;
    end
end

always_comb begin
    if (is_load) begin
        wb_sel = WB_SEL_MEM;
    end else if (is_jal || is_jalr) begin
        wb_sel = WB_SEL_PC;
    end else if (is_csr_inst) begin
        wb_sel = WB_SEL0; // Use WB_SEL0 to route csr_val_id
    end else begin
        wb_sel = WB_SEL_ALU;
    end
end

always_comb begin
    if (is_branch) begin
        case(funct3)
            BEQ_FUNCT3: cmp_op = CMP_EQ;
            BNE_FUNCT3: cmp_op = CMP_NE;
            BLT_FUNCT3: cmp_op = CMP_LT;
            BGE_FUNCT3: cmp_op = CMP_GE;
            BLTU_FUNCT3: cmp_op = CMP_LTU;
            BGEU_FUNCT3: cmp_op = CMP_GEU;
            default: cmp_op = CMP_NO;
        endcase
    end else begin
        cmp_op = CMP_NO;
    end
end

always_comb begin
    if (is_load || is_store) begin
        case(funct3)
            3'b000: mem_op = (is_load) ? MEM_B : MEM_B;
            3'b001: mem_op = (is_load) ? MEM_H : MEM_H;
            3'b010: mem_op = (is_load) ? MEM_W : MEM_W;
            3'b011: mem_op = (is_load) ? MEM_D : MEM_D;
            3'b100: mem_op = MEM_UB;
            3'b101: mem_op = MEM_UH;
            3'b110: mem_op = MEM_UW;
            default: mem_op = MEM_NO;
        endcase
    end else begin
        mem_op = MEM_NO;
    end
end

always_comb begin
    if (is_load || is_store || is_jalr || is_auipc || is_lui || is_jal || is_branch) begin
        alu_op = ALU_ADD;
    end else if (is_imm) begin
        case(funct3)
            ADD_FUNCT3: alu_op = ALU_ADD;
            SLL_FUNCT3: alu_op = ALU_SLL;
            SLT_FUNCT3: alu_op = ALU_SLT;
            SLTU_FUNCT3: alu_op = ALU_SLTU;
            XOR_FUNCT3: alu_op = ALU_XOR;
            SRL_FUNCT3: alu_op = (funct7[5] == 1'b1) ? ALU_SRA : ALU_SRL;
            OR_FUNCT3: alu_op = ALU_OR;
            AND_FUNCT3: alu_op = ALU_AND;
            default: alu_op = ALU_ADD;
        endcase
    end else if (is_reg) begin
        case(funct3)
            ADD_FUNCT3: alu_op = (funct7[5] == 1'b1) ? ALU_SUB : ALU_ADD;
            SLL_FUNCT3: alu_op = ALU_SLL;
            SLT_FUNCT3: alu_op = ALU_SLT;
            SLTU_FUNCT3: alu_op = ALU_SLTU;
            XOR_FUNCT3: alu_op = ALU_XOR;
            SRL_FUNCT3: alu_op = (funct7[5] == 1'b1) ? ALU_SRA : ALU_SRL;
            OR_FUNCT3: alu_op = ALU_OR;
            AND_FUNCT3: alu_op = ALU_AND;
            default: alu_op = ALU_ADD;
        endcase
    end else if (is_immw) begin
        case(funct3)
            ADD_FUNCT3: alu_op = ALU_ADDW;
            SLL_FUNCT3: alu_op = ALU_SLLW;
            SRL_FUNCT3: alu_op = (funct7[5] == 1'b1) ? ALU_SRAW : ALU_SRLW;
            default: alu_op = ALU_ADDW;
        endcase
    end else if (is_regw) begin
        case(funct3)
            ADD_FUNCT3: alu_op = (funct7[5] == 1'b1) ? ALU_SUBW : ALU_ADDW;
            SLL_FUNCT3: alu_op = ALU_SLLW;
            SRL_FUNCT3: alu_op = (funct7[5] == 1'b1) ? ALU_SRAW : ALU_SRLW;
            default: alu_op = ALU_ADDW;
        endcase
    end else begin
        alu_op = ALU_ADD;
    end
end

always_comb begin
    if (is_csrrw || is_csrrwi) begin
        csr_alu_op = CSR_ALU_ADD;
    end else if (is_csrrs || is_csrrsi) begin
        csr_alu_op = CSR_ALU_OR;
    end else if (is_csrrc || is_csrrci) begin
        csr_alu_op = CSR_ALU_ANDNOT;
    end else begin
        csr_alu_op = CSR_ALU_ADD;
    end
end

always_comb begin
    if (is_csrrwi || is_csrrsi || is_csrrci) begin
        csr_alu_asel = ASEL_CSR0; // Wait, actually the enum has ASEL_CSR0 and ASEL_CSRREG ? 
        // We will just use the enum values but evaluate it manually in Core.sv.
        // Let's say: ASEL_CSR0 = imm, ASEL_CSRREG = rs1.
        csr_alu_asel = ASEL_CSR0;
    end else begin
        csr_alu_asel = ASEL_CSRREG;
    end
end

always_comb begin
    // the enum has BSEL_CSR0, BSEL_GPREG, BSEL_CSRIMM
    // Actually we just need to pass csr_val.
    csr_alu_bsel = BSEL_CSR0; 
end

endmodule