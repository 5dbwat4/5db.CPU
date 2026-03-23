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
    // Memory FSM and Stalls
    // ========================================================================
    typedef enum logic [2:0] {
        IDLE, IF1, IF2, WAITFOR1, WAITFOR2, MEM1, MEM2
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (rst) state <= IDLE;
        else state <= next_state;
    end

    logic i_req_done, i_rep_done;
    logic d_req_done, d_rep_done;

    assign i_req_done = imem_ift.r_request_valid && imem_ift.r_request_ready;
    assign i_rep_done = imem_ift.r_reply_valid && imem_ift.r_reply_ready;

    assign d_req_done = (dmem_ift.r_request_valid && dmem_ift.r_request_ready) ||
                        (dmem_ift.w_request_valid && dmem_ift.w_request_ready);
    assign d_rep_done = (dmem_ift.r_reply_valid && dmem_ift.r_reply_ready) ||
                        (dmem_ift.w_reply_valid && dmem_ift.w_reply_ready);

    // Forward declaration of MEM stage signals
    logic re_mem_MEM, we_mem_MEM, valid_MEM;
    logic mem_req;
    assign mem_req = (re_mem_MEM | we_mem_MEM) && valid_MEM;

    always_comb begin
        case(state)
            IDLE: next_state = IF1;
            IF1: begin
                if (mem_req) begin
                    if (i_req_done) next_state = WAITFOR2;
                    else next_state = WAITFOR1;
                end else begin
                    if (i_req_done) next_state = IF2;
                    else next_state = IF1;
                end
            end
            WAITFOR1: begin
                if (i_req_done) next_state = WAITFOR2;
                else next_state = WAITFOR1;
            end
            WAITFOR2: begin
                if (i_rep_done) next_state = MEM1;
                else next_state = WAITFOR2;
            end
            IF2: begin
                if (i_rep_done) next_state = IDLE;
                else next_state = IF2;
            end
            MEM1: begin
                if (d_req_done) next_state = MEM2;
                else next_state = MEM1;
            end
            MEM2: begin
                if (d_rep_done) next_state = IDLE;
                else next_state = MEM2;
            end
            default: next_state = IDLE;
        endcase
    end

    assign imem_ift.r_request_valid = (state == IF1) || (state == WAITFOR1);
    assign imem_ift.r_reply_ready   = (state == IF2) || (state == WAITFOR2);

    assign dmem_ift.r_request_valid = (state == MEM1) && re_mem_MEM && valid_MEM;
    assign dmem_ift.w_request_valid = (state == MEM1) && we_mem_MEM && valid_MEM;
    assign dmem_ift.r_reply_ready   = (state == MEM2) && re_mem_MEM;
    assign dmem_ift.w_reply_ready   = (state == MEM2) && we_mem_MEM;
    
    // Unused imem write signals
    assign imem_ift.w_request_valid = 1'b0;
    assign imem_ift.w_request_bits.waddr = 64'b0;
    assign imem_ift.w_request_bits.wdata = 64'b0;
    assign imem_ift.w_request_bits.wmask = 8'b0;
    assign imem_ift.w_reply_ready = 1'b0;

    logic mem_stall, if_stall;
    assign mem_stall = mem_req && !(state == MEM2 && d_rep_done);
    assign if_stall = !( (state == IF2 && i_rep_done) || (state == WAITFOR2 && i_rep_done) );

    // ========================================================================
    // Pipeline stage signals
    // ========================================================================

    // IF stage signals
    addr_t pc;
    
    // IF/ID register signals
    logic  valid_ID;
    addr_t pc_ID;
    inst_t inst_ID_reg;

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
    logic is_branch_ID, is_load_ID, is_store_ID, is_jalr_ID, is_imm_ID, is_immw_ID, is_reg_ID, is_regw_ID;
    logic rs1_use_ID, rs2_use_ID;
    logic load_use_stall;

    // Forwarding logic
    data_t fw_rs1_data, fw_rs2_data;

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
    // valid_MEM, re_mem_MEM, we_mem_MEM declared above
    addr_t pc_MEM;
    inst_t inst_MEM;
    reg_ind_t rs1_MEM, rs2_MEM, rd_MEM;
    data_t rs1_data_MEM, rs2_data_MEM;
    logic we_reg_MEM;
    wb_sel_op_enum wb_sel_MEM;
    mem_op_enum mem_op_MEM;
    data_t alu_res_MEM, dmem_wdata_MEM;
    logic br_taken_MEM;
    addr_t npc_MEM;
    mask_t dmem_wmask_MEM;

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

    // Fetch Discard Logic
    logic discard_fetch;
    always_ff @(posedge clk) begin
        if (rst) discard_fetch <= 1'b0;
        else if (mem_stall || load_use_stall) discard_fetch <= discard_fetch;
        else if (flush_EX && if_stall) discard_fetch <= 1'b1;
        else if (!if_stall) discard_fetch <= 1'b0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 64'h0;
        end else if (mem_stall || load_use_stall) begin
            pc <= pc;
        end else if (flush_EX) begin
            pc <= target_pc_EX;
        end else if (!if_stall) begin
            if (discard_fetch) begin
                pc <= pc;
            end else begin
                pc <= pc + 4;
            end
        end
    end

    // Safe AXI Address Latch to prevent protocol violation
    logic hold_raddr;
    addr_t latched_raddr;

    always_ff @(posedge clk) begin
        if (rst) begin
            hold_raddr <= 1'b0;
            latched_raddr <= 64'b0;
        end else begin
            if (imem_ift.r_request_valid && !imem_ift.r_request_ready) begin
                if (!hold_raddr) begin
                    hold_raddr <= 1'b1;
                    latched_raddr <= pc;
                end
            end else begin
                hold_raddr <= 1'b0;
            end
        end
    end

    assign imem_ift.r_request_bits.raddr = hold_raddr ? latched_raddr : pc;

    // ========================================================================
    // IF/ID Register
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_ID <= 1'b0;
            pc_ID <= 64'b0;
            inst_ID_reg <= 32'h00000013;
        end else if (mem_stall || load_use_stall) begin
            valid_ID <= valid_ID;
            pc_ID <= pc_ID;
            inst_ID_reg <= inst_ID_reg;
        end else if (flush_EX) begin
            valid_ID <= 1'b0;
        end else if (!if_stall) begin
            valid_ID <= !discard_fetch;
            pc_ID <= pc;
            inst_ID_reg <= pc[2] ? imem_ift.r_reply_bits.rdata[63:32] : imem_ift.r_reply_bits.rdata[31:0];
        end else begin
            valid_ID <= 1'b0;
        end
    end

    // ========================================================================
    // ID Stage
    // ========================================================================

    assign inst_ID = valid_ID ? inst_ID_reg : 32'h00000013; // nop if invalid

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

    // Forwarding Logic
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

    // ========================================================================
    // ID/EX Register
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst) begin
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
        end else if (mem_stall) begin
            valid_EX <= valid_EX;
            pc_EX <= pc_EX;
            inst_EX <= inst_EX;
            rs1_EX <= rs1_EX;
            rs2_EX <= rs2_EX;
            rd_EX <= rd_EX;
            rs1_data_EX <= rs1_data_EX;
            rs2_data_EX <= rs2_data_EX;
            imm_EX <= imm_EX;
            we_reg_EX <= we_reg_EX;
            we_mem_EX <= we_mem_EX;
            re_mem_EX <= re_mem_EX;
            npc_sel_EX <= npc_sel_EX;
            alu_op_EX <= alu_op_EX;
            cmp_op_EX <= cmp_op_EX;
            alu_asel_EX <= alu_asel_EX;
            alu_bsel_EX <= alu_bsel_EX;
            wb_sel_EX <= wb_sel_EX;
            mem_op_EX <= mem_op_EX;
        end else if (flush_EX || load_use_stall) begin
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
            rs1_data_EX <= fw_rs1_data;
            rs2_data_EX <= fw_rs2_data;
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
            dmem_wmask_MEM <= 8'b0;
        end else if (mem_stall) begin
            valid_MEM <= valid_MEM;
            pc_MEM <= pc_MEM;
            inst_MEM <= inst_MEM;
            rs1_MEM <= rs1_MEM;
            rs2_MEM <= rs2_MEM;
            rd_MEM <= rd_MEM;
            rs1_data_MEM <= rs1_data_MEM;
            rs2_data_MEM <= rs2_data_MEM;
            we_reg_MEM <= we_reg_MEM;
            we_mem_MEM <= we_mem_MEM;
            re_mem_MEM <= re_mem_MEM;
            wb_sel_MEM <= wb_sel_MEM;
            mem_op_MEM <= mem_op_MEM;
            alu_res_MEM <= alu_res_MEM;
            dmem_wdata_MEM <= dmem_wdata_MEM;
            br_taken_MEM <= br_taken_MEM;
            npc_MEM <= npc_MEM;
            dmem_wmask_MEM <= dmem_wmask_MEM;
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
            dmem_wmask_MEM <= dmem_wmask_EX;
        end
    end

    // ========================================================================
    // MEM Stage
    // ========================================================================

    assign dmem_ift.r_request_bits.raddr = alu_res_MEM;
    assign dmem_ift.w_request_bits.waddr = alu_res_MEM;
    assign dmem_ift.w_request_bits.wdata = dmem_wdata_MEM;
    assign dmem_ift.w_request_bits.wmask = dmem_wmask_MEM;
    
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
        end else if (mem_stall) begin
            valid_WB <= 1'b0;
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
