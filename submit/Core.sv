`include "core_struct.vh"

module Core (
    input clk,
    input rst,

    Mem_ift.Master imem_ift,
    Mem_ift.Master dmem_ift,

    output logic cosim_valid,
    output CorePack::CoreInfo cosim_core_info
);

    import CorePack::*;

    // ========================================================================
    // Pipeline stage signals
    // ========================================================================

    // IF stage signals
    addr_t pc;
    
    // IF/ID register signals
    logic  valid_ID;
    addr_t pc_ID;

    // ID stage signals
    inst_t inst_ID;
    data_t imm_ID;
    reg_ind_t rs1_ID, rs2_ID, rd_ID;
    data_t rs1_data_ID, rs2_data_ID;
    logic we_reg_ID, we_mem_ID, re_mem_ID, npc_sel_ID;
    imm_op_enum immgen_op_ID;
    alu_op_enum alu_op_ID;
    cmp_op_enum cmp_op_ID;
    alu_asel_op_enum alu_asel_ID;
    alu_bsel_op_enum alu_bsel_ID;
    wb_sel_op_enum wb_sel_ID;
    mem_op_enum mem_op_ID;

    // ID/EX register signals
    logic valid_EX;
    addr_t pc_EX;
    inst_t inst_EX;
    reg_ind_t rs1_EX, rs2_EX, rd_EX;
    data_t rs1_data_EX, rs2_data_EX, imm_EX;
    logic we_reg_EX, we_mem_EX, re_mem_EX, npc_sel_EX;
    alu_op_enum alu_op_EX;
    cmp_op_enum cmp_op_EX;
    alu_asel_op_enum alu_asel_EX;
    alu_bsel_op_enum alu_bsel_EX;
    wb_sel_op_enum wb_sel_EX;
    mem_op_enum mem_op_EX;

    // EX stage signals
    data_t alu_a, alu_b, alu_res_EX;
    logic cmp_res_EX;
    logic br_taken_EX, is_jal_EX, is_jalr_EX;
    logic flush_EX;
    addr_t target_pc_EX, npc_EX;
    data_t dmem_wdata_EX;
    mask_t dmem_wmask_EX;

    // EX/MEM register signals
    logic valid_MEM;
    addr_t pc_MEM;
    inst_t inst_MEM;
    reg_ind_t rs1_MEM, rs2_MEM, rd_MEM;
    data_t rs1_data_MEM, rs2_data_MEM;
    logic we_reg_MEM, we_mem_MEM, re_mem_MEM;
    wb_sel_op_enum wb_sel_MEM;
    mem_op_enum mem_op_MEM;
    data_t alu_res_MEM, dmem_wdata_MEM;
    logic br_taken_MEM;
    addr_t npc_MEM;

    // MEM stage signals
    data_t dmem_rdata_MEM, mem_read_data_MEM;

    // MEM/WB register signals
    logic valid_WB;
    addr_t pc_WB;
    inst_t inst_WB;
    reg_ind_t rs1_WB, rs2_WB, rd_WB;
    data_t rs1_data_WB, rs2_data_WB;
    logic we_reg_WB, we_mem_WB;
    wb_sel_op_enum wb_sel_WB;
    data_t alu_res_WB, dmem_wdata_WB, mem_rdata_WB, mem_read_data_WB;
    logic br_taken_WB;
    addr_t npc_WB;

    // WB stage signals
    data_t wb_val_WB;

    // ========================================================================
    // IF Stage
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 64'h0;
        end else begin
            if (flush_EX) begin
                pc <= target_pc_EX;
            end else begin
                pc <= pc + 4;
            end
        end
    end

    assign imem_ift.r_request_valid = ~rst;
    assign imem_ift.r_request_bits.raddr = pc;
    assign imem_ift.r_reply_ready = 1'b1;

    assign imem_ift.w_request_valid = 1'b0;
    assign imem_ift.w_request_bits.waddr = 64'b0;
    assign imem_ift.w_request_bits.wdata = 64'b0;
    assign imem_ift.w_request_bits.wmask = 8'b0;
    assign imem_ift.w_reply_ready = 1'b0;

    // ========================================================================
    // IF/ID Register
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_ID <= 1'b0;
            pc_ID    <= 64'h0;
        end else begin
            valid_ID <= ~flush_EX;
            pc_ID    <= pc;
        end
    end

    // ========================================================================
    // ID Stage
    // ========================================================================

    wire [31:0] inst_ID_raw = pc_ID[2] ? imem_ift.r_reply_bits.rdata[63:32] : imem_ift.r_reply_bits.rdata[31:0];
    assign inst_ID = valid_ID ? inst_ID_raw : 32'h00000013; // default to nop if invalid

    assign rs1_ID = inst_ID[19:15];
    assign rs2_ID = inst_ID[24:20];
    assign rd_ID  = inst_ID[11:7];

    controller ctrl (
        .inst(inst_ID),
        .we_reg(we_reg_ID),
        .we_mem(we_mem_ID),
        .re_mem(re_mem_ID),
        .npc_sel(npc_sel_ID),
        .immgen_op(immgen_op_ID),
        .alu_op(alu_op_ID),
        .cmp_op(cmp_op_ID),
        .alu_asel(alu_asel_ID),
        .alu_bsel(alu_bsel_ID),
        .wb_sel(wb_sel_ID),
        .mem_op(mem_op_ID)
    );

    ImmGen imm_gen_inst (
        .inst(inst_ID),
        .imm_op(immgen_op_ID),
        .imm(imm_ID)
    );

    RegFile reg_file_inst (
        .clk(clk),
        .rst(rst),
        .we(we_reg_WB && valid_WB),
        .read_addr_1(rs1_ID),
        .read_addr_2(rs2_ID),
        .write_addr(rd_WB),
        .write_data(wb_val_WB),
        .read_data_1(rs1_data_ID),
        .read_data_2(rs2_data_ID)
    );

    // ========================================================================
    // ID/EX Register
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst || flush_EX) begin
            valid_EX <= 1'b0;
            pc_EX <= 64'b0;
            inst_EX <= 32'h00000013;
            rs1_EX <= 5'b0;
            rs2_EX <= 5'b0;
            rd_EX <= 5'b0;
            rs1_data_EX <= 64'b0;
            rs2_data_EX <= 64'b0;
            imm_EX <= 64'b0;
            we_reg_EX <= 1'b0;
            we_mem_EX <= 1'b0;
            re_mem_EX <= 1'b0;
            npc_sel_EX <= 1'b0;
            alu_op_EX <= ALU_ADD;
            cmp_op_EX <= CMP_NO;
            alu_asel_EX <= ASEL_REG;
            alu_bsel_EX <= BSEL_REG;
            wb_sel_EX <= WB_SEL_ALU;
            mem_op_EX <= MEM_NO;
        end else begin
            valid_EX <= valid_ID;
            pc_EX <= pc_ID;
            inst_EX <= inst_ID;
            rs1_EX <= rs1_ID;
            rs2_EX <= rs2_ID;
            rd_EX <= rd_ID;
            rs1_data_EX <= rs1_data_ID;
            rs2_data_EX <= rs2_data_ID;
            imm_EX <= imm_ID;
            we_reg_EX <= we_reg_ID;
            we_mem_EX <= we_mem_ID;
            re_mem_EX <= re_mem_ID;
            npc_sel_EX <= npc_sel_ID;
            alu_op_EX <= alu_op_ID;
            cmp_op_EX <= cmp_op_ID;
            alu_asel_EX <= alu_asel_ID;
            alu_bsel_EX <= alu_bsel_ID;
            wb_sel_EX <= wb_sel_ID;
            mem_op_EX <= mem_op_ID;
        end
    end

    // ========================================================================
    // EX Stage
    // ========================================================================

    always_comb begin
        case(alu_asel_EX)
            ASEL_REG: alu_a = rs1_data_EX;
            ASEL_PC:  alu_a = pc_EX;
            ASEL0:    alu_a = 64'b0;
            default:  alu_a = rs1_data_EX;
        endcase
    end

    always_comb begin
        case(alu_bsel_EX)
            BSEL_REG: alu_b = rs2_data_EX;
            BSEL_IMM: alu_b = imm_EX;
            BSEL0:    alu_b = 64'b0;
            default:  alu_b = rs2_data_EX;
        endcase
    end

    ALU alu_inst (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op_EX),
        .res(alu_res_EX)
    );

    Cmp cmp_inst (
        .a(rs1_data_EX),
        .b(rs2_data_EX),
        .cmp_op(cmp_op_EX),
        .cmp_res(cmp_res_EX)
    );

    wire [6:0] opcode_EX = inst_EX[6:0];
    assign br_taken_EX = (opcode_EX == BRANCH_OPCODE) ? cmp_res_EX : 1'b0;
    assign is_jal_EX   = (opcode_EX == JAL_OPCODE);
    assign is_jalr_EX  = (opcode_EX == JALR_OPCODE);

    assign flush_EX = valid_EX && (br_taken_EX || is_jal_EX || is_jalr_EX);

    always_comb begin
        if (is_jalr_EX) begin
            target_pc_EX = alu_res_EX & ~64'b1;
        end else begin
            target_pc_EX = pc_EX + imm_EX;
        end
    end

    assign npc_EX = flush_EX ? target_pc_EX : (pc_EX + 4);

    DataPkg data_pkg_inst (
        .mem_op(mem_op_EX),
        .reg_data(rs2_data_EX),
        .dmem_waddr(alu_res_EX),
        .dmem_wdata(dmem_wdata_EX)
    );

    MaskGen mask_gen_inst (
        .mem_op(mem_op_EX),
        .dmem_waddr(alu_res_EX),
        .dmem_wmask(dmem_wmask_EX)
    );

    assign dmem_ift.r_request_valid = ~rst && re_mem_EX && valid_EX;
    assign dmem_ift.w_request_valid = ~rst && we_mem_EX && valid_EX;
    assign dmem_ift.r_request_bits.raddr = alu_res_EX;
    assign dmem_ift.w_request_bits.waddr = alu_res_EX;
    assign dmem_ift.w_request_bits.wdata = dmem_wdata_EX;
    assign dmem_ift.w_request_bits.wmask = dmem_wmask_EX;
    assign dmem_ift.r_reply_ready = 1'b1;
    assign dmem_ift.w_reply_ready = 1'b1;

    // ========================================================================
    // EX/MEM Register
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_MEM <= 1'b0;
            pc_MEM <= 64'b0;
            inst_MEM <= 32'h00000013;
            rs1_MEM <= 5'b0;
            rs2_MEM <= 5'b0;
            rd_MEM <= 5'b0;
            rs1_data_MEM <= 64'b0;
            rs2_data_MEM <= 64'b0;
            we_reg_MEM <= 1'b0;
            we_mem_MEM <= 1'b0;
            re_mem_MEM <= 1'b0;
            wb_sel_MEM <= WB_SEL_ALU;
            mem_op_MEM <= MEM_NO;
            alu_res_MEM <= 64'b0;
            dmem_wdata_MEM <= 64'b0;
            br_taken_MEM <= 1'b0;
            npc_MEM <= 64'b0;
        end else begin
            valid_MEM <= valid_EX;
            pc_MEM <= pc_EX;
            inst_MEM <= inst_EX;
            rs1_MEM <= rs1_EX;
            rs2_MEM <= rs2_EX;
            rd_MEM <= rd_EX;
            rs1_data_MEM <= rs1_data_EX;
            rs2_data_MEM <= rs2_data_EX;
            we_reg_MEM <= we_reg_EX;
            we_mem_MEM <= we_mem_EX;
            re_mem_MEM <= re_mem_EX;
            wb_sel_MEM <= wb_sel_EX;
            mem_op_MEM <= mem_op_EX;
            alu_res_MEM <= alu_res_EX;
            dmem_wdata_MEM <= dmem_wdata_EX;
            br_taken_MEM <= br_taken_EX;
            npc_MEM <= npc_EX;
        end
    end

    // ========================================================================
    // MEM Stage
    // ========================================================================

    assign dmem_rdata_MEM = dmem_ift.r_reply_bits.rdata;

    DataTrunc data_trunc_inst (
        .dmem_rdata(dmem_rdata_MEM),
        .mem_op(mem_op_MEM),
        .dmem_raddr(alu_res_MEM),
        .read_data(mem_read_data_MEM)
    );

    // ========================================================================
    // MEM/WB Register
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_WB <= 1'b0;
            pc_WB <= 64'b0;
            inst_WB <= 32'h00000013;
            rs1_WB <= 5'b0;
            rs2_WB <= 5'b0;
            rd_WB <= 5'b0;
            rs1_data_WB <= 64'b0;
            rs2_data_WB <= 64'b0;
            we_reg_WB <= 1'b0;
            we_mem_WB <= 1'b0;
            wb_sel_WB <= WB_SEL_ALU;
            alu_res_WB <= 64'b0;
            dmem_wdata_WB <= 64'b0;
            mem_rdata_WB <= 64'b0;
            mem_read_data_WB <= 64'b0;
            br_taken_WB <= 1'b0;
            npc_WB <= 64'b0;
        end else begin
            valid_WB <= valid_MEM;
            pc_WB <= pc_MEM;
            inst_WB <= inst_MEM;
            rs1_WB <= rs1_MEM;
            rs2_WB <= rs2_MEM;
            rd_WB <= rd_MEM;
            rs1_data_WB <= rs1_data_MEM;
            rs2_data_WB <= rs2_data_MEM;
            we_reg_WB <= we_reg_MEM;
            we_mem_WB <= we_mem_MEM;
            wb_sel_WB <= wb_sel_MEM;
            alu_res_WB <= alu_res_MEM;
            dmem_wdata_WB <= dmem_wdata_MEM;
            mem_rdata_WB <= dmem_rdata_MEM;
            mem_read_data_WB <= mem_read_data_MEM;
            br_taken_WB <= br_taken_MEM;
            npc_WB <= npc_MEM;
        end
    end

    // ========================================================================
    // WB Stage
    // ========================================================================

    always_comb begin
        case(wb_sel_WB)
            WB_SEL_ALU: wb_val_WB = alu_res_WB;
            WB_SEL_MEM: wb_val_WB = mem_read_data_WB;
            WB_SEL_PC:  wb_val_WB = pc_WB + 4;
            default:    wb_val_WB = 64'b0;
        endcase
    end

    // ========================================================================
    // Cosimulation Output
    // ========================================================================

    assign cosim_valid = valid_WB;
    
    assign cosim_core_info.pc        = pc_WB;
    assign cosim_core_info.inst      = {32'b0, inst_WB};   
    assign cosim_core_info.rs1_id    = {59'b0, rs1_WB};
    assign cosim_core_info.rs1_data  = rs1_data_WB;
    assign cosim_core_info.rs2_id    = {59'b0, rs2_WB};
    assign cosim_core_info.rs2_data  = rs2_data_WB;
    assign cosim_core_info.alu       = alu_res_WB;
    assign cosim_core_info.mem_addr  = alu_res_WB;
    assign cosim_core_info.mem_we    = {63'b0, we_mem_WB};
    assign cosim_core_info.mem_wdata = dmem_wdata_WB;
    assign cosim_core_info.mem_rdata = mem_rdata_WB;
    assign cosim_core_info.rd_we     = {63'b0, we_reg_WB && valid_WB};
    assign cosim_core_info.rd_id     = {59'b0, rd_WB}; 
    assign cosim_core_info.rd_data   = wb_val_WB;
    assign cosim_core_info.br_taken  = {63'b0, br_taken_WB};
    assign cosim_core_info.npc       = npc_WB;

endmodule
