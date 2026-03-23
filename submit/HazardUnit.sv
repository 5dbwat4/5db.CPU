`include "core_struct.vh"

module HazardUnit (
    input CorePack::inst_t inst_ID,
    input CorePack::reg_ind_t rs1_ID,
    input CorePack::reg_ind_t rs2_ID,
    input CorePack::data_t rs1_data_ID,
    input CorePack::data_t rs2_data_ID,
    
    input logic valid_EX,
    input CorePack::reg_ind_t rd_EX,
    input logic we_reg_EX,
    input CorePack::wb_sel_op_enum wb_sel_EX,
    input CorePack::data_t alu_res_EX,
    input CorePack::addr_t pc_EX,
    
    input logic valid_MEM,
    input CorePack::reg_ind_t rd_MEM,
    input logic we_reg_MEM,
    input CorePack::wb_sel_op_enum wb_sel_MEM,
    input CorePack::data_t alu_res_MEM,
    input CorePack::addr_t pc_MEM,
    input CorePack::data_t mem_read_data_MEM,
    
    input logic valid_WB,
    input CorePack::reg_ind_t rd_WB,
    input logic we_reg_WB,
    input CorePack::data_t wb_val_WB,
    
    output logic load_use_stall,
    output CorePack::data_t fw_rs1_data,
    output CorePack::data_t fw_rs2_data
);

    import CorePack::*;

    logic is_branch_ID, is_load_ID, is_store_ID, is_jalr_ID, is_imm_ID, is_immw_ID, is_reg_ID, is_regw_ID;
    logic rs1_use_ID, rs2_use_ID;

    assign is_branch_ID = (inst_ID[6:0] == BRANCH_OPCODE);
    assign is_load_ID   = (inst_ID[6:0] == LOAD_OPCODE);
    assign is_store_ID  = (inst_ID[6:0] == STORE_OPCODE);
    assign is_jalr_ID   = (inst_ID[6:0] == JALR_OPCODE);
    assign is_imm_ID    = (inst_ID[6:0] == IMM_OPCODE);
    assign is_immw_ID   = (inst_ID[6:0] == IMMW_OPCODE);
    assign is_reg_ID    = (inst_ID[6:0] == REG_OPCODE);
    assign is_regw_ID   = (inst_ID[6:0] == REGW_OPCODE);

    assign rs1_use_ID = is_branch_ID | is_load_ID | is_store_ID | is_jalr_ID | is_imm_ID | is_immw_ID | is_reg_ID | is_regw_ID;
    assign rs2_use_ID = is_branch_ID | is_store_ID | is_reg_ID | is_regw_ID;

    assign load_use_stall = valid_EX && (wb_sel_EX == WB_SEL_MEM) && rd_EX != 5'b0 && (
        (rs1_use_ID && rd_EX == rs1_ID) || 
        (rs2_use_ID && rd_EX == rs2_ID)
    );

    data_t wb_val_EX;
    always_comb begin
        case(wb_sel_EX)
            WB_SEL_ALU: wb_val_EX = alu_res_EX;
            WB_SEL_PC:  wb_val_EX = pc_EX + 4;
            default:    wb_val_EX = alu_res_EX;
        endcase
    end

    data_t wb_val_MEM;
    always_comb begin
        case(wb_sel_MEM)
            WB_SEL_ALU: wb_val_MEM = alu_res_MEM;
            WB_SEL_PC:  wb_val_MEM = pc_MEM + 4;
            WB_SEL_MEM: wb_val_MEM = mem_read_data_MEM;
            default:    wb_val_MEM = alu_res_MEM;
        endcase
    end

    always_comb begin
        if (valid_EX && we_reg_EX && rd_EX != 5'b0 && rd_EX == rs1_ID && wb_sel_EX != WB_SEL_MEM) begin
            fw_rs1_data = wb_val_EX;
        end else if (valid_MEM && we_reg_MEM && rd_MEM != 5'b0 && rd_MEM == rs1_ID) begin
            fw_rs1_data = wb_val_MEM;
        end else if (valid_WB && we_reg_WB && rd_WB != 5'b0 && rd_WB == rs1_ID) begin
            fw_rs1_data = wb_val_WB;
        end else begin
            fw_rs1_data = rs1_data_ID;
        end
    end

    always_comb begin
        if (valid_EX && we_reg_EX && rd_EX != 5'b0 && rd_EX == rs2_ID && wb_sel_EX != WB_SEL_MEM) begin
            fw_rs2_data = wb_val_EX;
        end else if (valid_MEM && we_reg_MEM && rd_MEM != 5'b0 && rd_MEM == rs2_ID) begin
            fw_rs2_data = wb_val_MEM;
        end else if (valid_WB && we_reg_WB && rd_WB != 5'b0 && rd_WB == rs2_ID) begin
            fw_rs2_data = wb_val_WB;
        end else begin
            fw_rs2_data = rs2_data_ID;
        end
    end

endmodule