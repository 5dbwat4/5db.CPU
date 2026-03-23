`include "core_struct.vh"
`include "csr_struct.vh"

module Core (
    input clk,
    input rst,
    input time_int,

    Mem_ift.Master imem_ift,
    Mem_ift.Master dmem_ift,

    output cosim_valid,
    output CorePack::CoreInfo cosim_core_info,
    output CsrPack::CSRPack cosim_csr_info,
    output cosim_interrupt,
    output cosim_switch_mode,
    output CorePack::data_t cosim_cause
);

    import CorePack::*;
    import CsrPack::*;

    // ========================================================================
    // Memory FSM and Stalls
    // ========================================================================
    
    logic re_mem_MEM, we_mem_MEM, valid_MEM;
    logic mem_stall, if_stall;

    MemFSM mem_fsm_inst (
        .clk(clk),
        .rst(rst),
        .imem_ift(imem_ift),
        .dmem_ift(dmem_ift),
        .re_mem_MEM(re_mem_MEM),
        .we_mem_MEM(we_mem_MEM),
        .valid_MEM(valid_MEM),
        .mem_stall(mem_stall),
        .if_stall(if_stall)
    );

    // ========================================================================
    // CSRModule Signals
    // ========================================================================
    
    logic [1:0] priv;
    logic switch_mode;
    data_t pc_csr;

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
    
    logic we_csr_ID;
    logic [1:0] csr_ret_ID;
    csr_alu_op_enmu csr_alu_op_ID;
    csr_alu_asel_op_enum csr_alu_asel_ID;
    csr_alu_bsel_op_enum csr_alu_bsel_ID;

    logic load_use_stall;
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
    
    logic we_csr_EX;
    logic [1:0] csr_ret_EX;
    csr_alu_op_enmu csr_alu_op_EX;
    csr_alu_asel_op_enum csr_alu_asel_EX;
    csr_alu_bsel_op_enum csr_alu_bsel_EX;
    data_t csr_val_EX;
    csr_reg_ind_t csr_addr_EX;

    // EX stage signals
    data_t alu_a, alu_b, alu_res_EX;
    logic cmp_res_EX;
    logic br_taken_EX, is_jal_EX, is_jalr_EX;
    logic flush_EX;
    addr_t target_pc_EX, npc_EX;
    data_t dmem_wdata_EX;
    mask_t dmem_wmask_EX;
    
    data_t csr_alu_a, csr_alu_b, csr_alu_res_EX;

    // EX/MEM register signals
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
    
    logic we_csr_MEM;
    logic [1:0] csr_ret_MEM;
    data_t csr_alu_res_MEM;
    csr_reg_ind_t csr_addr_MEM;
    data_t csr_val_MEM;

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
    
    logic we_csr_WB;
    logic [1:0] csr_ret_WB;
    data_t csr_alu_res_WB;
    csr_reg_ind_t csr_addr_WB;
    data_t csr_val_WB;

    // WB stage signals
    data_t wb_val_WB;

    // ========================================================================
    // IF Stage
    // ========================================================================

    logic discard_fetch;
    always_ff @(posedge clk) begin
        if (rst) discard_fetch <= 1'b0;
        else if (switch_mode) begin
            if (if_stall) discard_fetch <= 1'b1;
            else discard_fetch <= 1'b0;
        end
        else if (mem_stall || load_use_stall) discard_fetch <= discard_fetch;
        else if (flush_EX && if_stall) discard_fetch <= 1'b1;
        else if (!if_stall) discard_fetch <= 1'b0;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 64'h0;
        end else if (switch_mode) begin
            pc <= pc_csr;
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

    logic hold_raddr;
    addr_t latched_raddr;

    always_ff @(posedge clk) begin
        if (rst || switch_mode) begin
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
        if (rst || switch_mode) begin
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

    assign inst_ID = valid_ID ? inst_ID_reg : 32'h00000013;

    assign rs1_ID = inst_ID[19:15];
    assign rs2_ID = inst_ID[24:20];
    assign rd_ID  = inst_ID[11:7];
    
    csr_reg_ind_t csr_addr_ID;
    assign csr_addr_ID = inst_ID[31:20];
    data_t csr_val_ID;

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
        .mem_op(mem_op_ID),
        .we_csr(we_csr_ID),
        .csr_ret(csr_ret_ID),
        .csr_alu_op(csr_alu_op_ID),
        .csr_alu_asel(csr_alu_asel_ID),
        .csr_alu_bsel(csr_alu_bsel_ID)
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

    ExceptPack except_id;
    assign except_id = '{except:1'b0, epc:64'b0, ecause:64'h0, etval:64'h0};
    
    ExceptPack except_exe;
    logic except_happen_id;
    
    IDExceptExamine id_except_examine (
        .clk(clk),
        .rst(rst),
        .stall(mem_stall || load_use_stall),
        .flush(flush_EX || switch_mode),
        .pc_id(pc_ID),
        .priv(priv),
        .inst_id(inst_ID),
        .valid_id(valid_ID),
        .except_id(except_id),
        .except_exe(except_exe),
        .except_happen_id(except_happen_id)
    );

    HazardUnit hazard_unit_inst (
        .inst_ID(inst_ID),
        .rs1_ID(rs1_ID),
        .rs2_ID(rs2_ID),
        .rs1_data_ID(rs1_data_ID),
        .rs2_data_ID(rs2_data_ID),
        
        .valid_EX(valid_EX),
        .rd_EX(rd_EX),
        .we_reg_EX(we_reg_EX),
        .wb_sel_EX(wb_sel_EX),
        .alu_res_EX(alu_res_EX),
        .pc_EX(pc_EX),
        .csr_val_EX(csr_val_EX),
        
        .valid_MEM(valid_MEM),
        .rd_MEM(rd_MEM),
        .we_reg_MEM(we_reg_MEM),
        .wb_sel_MEM(wb_sel_MEM),
        .alu_res_MEM(alu_res_MEM),
        .pc_MEM(pc_MEM),
        .mem_read_data_MEM(mem_read_data_MEM),
        .csr_val_MEM(csr_val_MEM),
        
        .valid_WB(valid_WB),
        .rd_WB(rd_WB),
        .we_reg_WB(we_reg_WB),
        .wb_val_WB(wb_val_WB),
        
        .load_use_stall(load_use_stall),
        .fw_rs1_data(fw_rs1_data),
        .fw_rs2_data(fw_rs2_data)
    );

    // ========================================================================
    // ID/EX Register
    // ========================================================================

    always_ff @(posedge clk) begin
        if (rst || switch_mode) begin
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
            
            we_csr_EX <= 1'b0;
            csr_ret_EX <= 2'b0;
            csr_alu_op_EX <= CSR_ALU_ADD;
            csr_alu_asel_EX <= ASEL_CSRREG;
            csr_alu_bsel_EX <= BSEL_CSR0;
            csr_val_EX <= 64'b0;
            csr_addr_EX <= 12'b0;
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
            
            we_csr_EX <= we_csr_EX;
            csr_ret_EX <= csr_ret_EX;
            csr_alu_op_EX <= csr_alu_op_EX;
            csr_alu_asel_EX <= csr_alu_asel_EX;
            csr_alu_bsel_EX <= csr_alu_bsel_EX;
            csr_val_EX <= csr_val_EX;
            csr_addr_EX <= csr_addr_EX;
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
            
            we_csr_EX <= 1'b0;
            csr_ret_EX <= 2'b0;
            csr_alu_op_EX <= CSR_ALU_ADD;
            csr_alu_asel_EX <= ASEL_CSRREG;
            csr_alu_bsel_EX <= BSEL_CSR0;
            csr_val_EX <= 64'b0;
            csr_addr_EX <= 12'b0;
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
            
            we_csr_EX <= we_csr_ID;
            csr_ret_EX <= csr_ret_ID;
            csr_alu_op_EX <= csr_alu_op_ID;
            csr_alu_asel_EX <= csr_alu_asel_ID;
            csr_alu_bsel_EX <= csr_alu_bsel_ID;
            csr_val_EX <= csr_val_ID;
            csr_addr_EX <= csr_addr_ID;
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
    
    // CSR ALU
    always_comb begin
        case(csr_alu_asel_EX)
            ASEL_CSR0:   csr_alu_a = imm_EX;
            ASEL_CSRREG: csr_alu_a = rs1_data_EX;
            default:     csr_alu_a = rs1_data_EX;
        endcase
    end
    always_comb begin
        case(csr_alu_bsel_EX)
            BSEL_CSR0:   csr_alu_b = csr_val_EX;
            default:     csr_alu_b = csr_val_EX;
        endcase
    end

    CSR_ALU csr_alu_inst (
        .a(csr_alu_a),
        .b(csr_alu_b),
        .alu_op(csr_alu_op_EX),
        .res(csr_alu_res_EX)
    );

    // ========================================================================
    // EX/MEM Register
    // ========================================================================

    ExceptPack except_MEM;
    ExceptReg exceptreg_MEM (
        .clk(clk),
        .rst(rst),
        .stall(mem_stall),
        .flush(switch_mode),
        .except_i(except_exe),
        .except_o(except_MEM)
    );

    always_ff @(posedge clk) begin
        if (rst || switch_mode) begin
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
            
            we_csr_MEM <= 1'b0;
            csr_ret_MEM <= 2'b0;
            csr_alu_res_MEM <= 64'b0;
            csr_addr_MEM <= 12'b0;
            csr_val_MEM <= 64'b0;
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
            
            we_csr_MEM <= we_csr_MEM;
            csr_ret_MEM <= csr_ret_MEM;
            csr_alu_res_MEM <= csr_alu_res_MEM;
            csr_addr_MEM <= csr_addr_MEM;
            csr_val_MEM <= csr_val_MEM;
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
            
            we_csr_MEM <= we_csr_EX;
            csr_ret_MEM <= csr_ret_EX;
            csr_alu_res_MEM <= csr_alu_res_EX;
            csr_addr_MEM <= csr_addr_EX;
            csr_val_MEM <= csr_val_EX;
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

    ExceptPack except_WB;
    ExceptReg exceptreg_WB (
        .clk(clk),
        .rst(rst),
        .stall(mem_stall),
        .flush(switch_mode),
        .except_i(except_MEM),
        .except_o(except_WB)
    );

    always_ff @(posedge clk) begin
        if (rst || switch_mode) begin
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
            
            we_csr_WB <= 1'b0;
            csr_ret_WB <= 2'b0;
            csr_alu_res_WB <= 64'b0;
            csr_addr_WB <= 12'b0;
            csr_val_WB <= 64'b0;
        end else if (mem_stall) begin
            valid_WB <= 1'b0; // Bubble generated due to stall
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
            
            we_csr_WB <= we_csr_MEM;
            csr_ret_WB <= csr_ret_MEM;
            csr_alu_res_WB <= csr_alu_res_MEM;
            csr_addr_WB <= csr_addr_MEM;
            csr_val_WB <= csr_val_MEM;
        end
    end

    // ========================================================================
    // WB Stage & CSRModule
    // ========================================================================

    always_comb begin
        case(wb_sel_WB)
            WB_SEL_ALU: wb_val_WB = alu_res_WB;
            WB_SEL_MEM: wb_val_WB = mem_read_data_WB;
            WB_SEL_PC:  wb_val_WB = pc_WB + 4;
            WB_SEL0:    wb_val_WB = csr_val_WB;
            default:    wb_val_WB = 64'b0;
        endcase
    end

    CSRModule csr_module_inst (
        .clk(clk),
        .rst(rst),
        .csr_we_wb(we_csr_WB && valid_WB),
        .csr_addr_wb(csr_addr_WB),
        .csr_val_wb(csr_alu_res_WB),
        .csr_addr_id(csr_addr_ID),
        .csr_val_id(csr_val_ID),
        .pc_ret(npc_WB),
        .valid_wb(valid_WB),
        .time_int(time_int),
        .csr_ret(valid_WB ? csr_ret_WB : 2'b0),
        .except_commit(except_WB),
        
        .priv(priv),
        .switch_mode(switch_mode),
        .pc_csr(pc_csr),
        
        .cosim_interrupt(cosim_interrupt),
        .cosim_cause(cosim_cause),
        .cosim_csr_info(cosim_csr_info)
    );

    // ========================================================================
    // Cosimulation Output
    // ========================================================================

    assign cosim_switch_mode = switch_mode;
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
    assign cosim_core_info.npc       = switch_mode ? pc_csr : npc_WB;

endmodule
