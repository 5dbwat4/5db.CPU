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
    
    // FSM and Control Signals
    logic stall;
    logic inst_en;
    logic we_mem, re_mem;
    logic cosim_valid_fsm;
    assign cosim_valid = cosim_valid_fsm;
    
    // PC
    addr_t pc;
    addr_t next_pc;

    // IR (Instruction Register)
    inst_t inst_reg;
    inst_t current_inst;
    // During S_IF2 when inst_en is high, current_inst is the newly fetched instruction.
    // In other states, it's the saved instruction in inst_reg.
    assign current_inst = inst_en ? (pc[2] ? imem_ift.r_reply_bits.rdata[63:32] : imem_ift.r_reply_bits.rdata[31:0]) : inst_reg;

    always_ff @(posedge clk) begin
        if (rst) inst_reg <= 32'b0;
        else if (inst_en) inst_reg <= current_inst;
    end

    // Decode
    logic we_reg;
    logic npc_sel;
    imm_op_enum immgen_op;
    alu_op_enum alu_op;
    cmp_op_enum cmp_op;
    alu_asel_op_enum alu_asel;
    alu_bsel_op_enum alu_bsel;
    wb_sel_op_enum wb_sel;
    mem_op_enum mem_op;

    controller ctrl (
        .inst(current_inst),
        .we_reg(we_reg),
        .we_mem(we_mem),
        .re_mem(re_mem),
        .npc_sel(npc_sel),
        .immgen_op(immgen_op),
        .alu_op(alu_op),
        .cmp_op(cmp_op),
        .alu_asel(alu_asel),
        .alu_bsel(alu_bsel),
        .wb_sel(wb_sel),
        .mem_op(mem_op)
    );

    data_t imm;
    ImmGen imm_gen_inst (
        .inst(current_inst),
        .imm_op(immgen_op),
        .imm(imm)
    );

    // Register file
    reg_ind_t rs1;
    reg_ind_t rs2;
    reg_ind_t rd;
    assign rs1 = current_inst[19:15];
    assign rs2 = current_inst[24:20];
    assign rd = current_inst[11:7];

    data_t read_data_1;
    data_t read_data_2;
    data_t wb_val;

    RegFile reg_file_inst (
        .clk(clk),
        .rst(rst),
        .we(we_reg && cosim_valid_fsm),
        .read_addr_1(rs1),
        .read_addr_2(rs2),
        .write_addr(rd),
        .write_data(wb_val),
        .read_data_1(read_data_1),
        .read_data_2(read_data_2)
    );

    // EXE stage
    data_t alu_a;
    data_t alu_b;

    always_comb begin
        case(alu_asel)
            ASEL_REG: alu_a = read_data_1;
            ASEL_PC:  alu_a = pc;
            ASEL0:    alu_a = 64'b0;
            default:  alu_a = read_data_1;
        endcase
    end

    always_comb begin
        case(alu_bsel)
            BSEL_REG: alu_b = read_data_2;
            BSEL_IMM: alu_b = imm;
            BSEL0:    alu_b = 64'b0;
            default:  alu_b = read_data_2;
        endcase
    end

    data_t alu_res;
    ALU alu_inst (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .res(alu_res)
    );

    logic cmp_res;
    Cmp cmp_inst (
        .a(read_data_1),
        .b(read_data_2),
        .cmp_op(cmp_op),
        .cmp_res(cmp_res)
    );

    // Next PC calculation
    logic br_taken;
    assign br_taken = (current_inst[6:0] == BRANCH_OPCODE) ? cmp_res : 1'b0;
    
    addr_t pc_plus_4;
    assign pc_plus_4 = pc + 4;
    
    always_comb begin
        if (current_inst[6:0] == JALR_OPCODE) begin
            next_pc = (alu_res) & ~64'b1;
        end else if (br_taken || current_inst[6:0] == JAL_OPCODE) begin
            next_pc = pc + imm;
        end else begin
            next_pc = pc_plus_4;
        end
    end

    // MEM stage
    data_t dmem_wdata;
    mask_t dmem_wmask;

    DataPkg data_pkg_inst (
        .mem_op(mem_op),
        .reg_data(read_data_2),
        .dmem_waddr(alu_res),
        .dmem_wdata(dmem_wdata)
    );

    MaskGen mask_gen_inst (
        .mem_op(mem_op),
        .dmem_waddr(alu_res),
        .dmem_wmask(dmem_wmask)
    );

    data_t mem_read_data;
    DataTrunc data_trunc_inst (
        .dmem_rdata(dmem_ift.r_reply_bits.rdata),
        .mem_op(mem_op),
        .dmem_raddr(alu_res),
        .read_data(mem_read_data)
    );

    // WB stage
    always_comb begin
        case(wb_sel)
            WB_SEL_ALU: wb_val = alu_res;
            WB_SEL_MEM: wb_val = mem_read_data;
            WB_SEL_PC:  wb_val = pc_plus_4;
            default:    wb_val = 64'b0;
        endcase
    end

    // FSM
    MultiFSM fsm (
        .clk(clk),
        .rst(rst),
        .imem_ift(imem_ift),
        .dmem_ift(dmem_ift),
        .we_mem(we_mem),
        .re_mem(re_mem),
        .pc(pc),
        .alu_res(alu_res),
        .data_package(dmem_wdata),
        .mask_package(dmem_wmask),
        .stall(stall),
        .inst_en(inst_en),
        .cosim_valid(cosim_valid_fsm)
    );

    // PC Update
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 64'h0;
        end else if (cosim_valid_fsm) begin
            pc <= next_pc;
        end
    end

    assign cosim_core_info.pc        = pc;
    assign cosim_core_info.inst      = {32'b0, current_inst};   
    assign cosim_core_info.rs1_id    = {59'b0, rs1};
    assign cosim_core_info.rs1_data  = read_data_1;
    assign cosim_core_info.rs2_id    = {59'b0, rs2};
    assign cosim_core_info.rs2_data  = read_data_2;
    assign cosim_core_info.alu       = alu_res;
    assign cosim_core_info.mem_addr  = alu_res;
    assign cosim_core_info.mem_we    = {63'b0, dmem_ift.w_request_valid};
    assign cosim_core_info.mem_wdata = dmem_ift.w_request_bits.wdata;
    assign cosim_core_info.mem_rdata = dmem_ift.r_reply_bits.rdata;
    assign cosim_core_info.rd_we     = {63'b0, we_reg && cosim_valid_fsm};
    assign cosim_core_info.rd_id     = {59'b0, rd}; 
    assign cosim_core_info.rd_data   = wb_val;
    assign cosim_core_info.br_taken  = {63'b0, br_taken};
    assign cosim_core_info.npc       = next_pc;

endmodule

module MultiFSM(
    input clk,
    input rst,
    Mem_ift.Master imem_ift,
    Mem_ift.Master dmem_ift,
    input we_mem,
    input re_mem,
    input CorePack::addr_t pc,
    input CorePack::addr_t alu_res,
    input CorePack::data_t data_package,
    input CorePack::mask_t mask_package,
    output logic stall,
    output logic inst_en,
    output logic cosim_valid
);
    import CorePack::*;

    typedef enum logic [1:0] {
        S_IF1, S_IF2, S_ID_EXE, S_MEM
    } state_t;

    state_t state, next_state;

    always_ff @(posedge clk) begin
        if (rst) state <= S_IF1;
        else state <= next_state;
    end

    always_comb begin
        case(state)
            S_IF1: begin
                if (imem_ift.r_request_valid && imem_ift.r_request_ready) next_state = S_IF2;
                else next_state = S_IF1;
            end
            S_IF2: begin
                if (imem_ift.r_reply_valid && imem_ift.r_reply_ready) next_state = S_ID_EXE;
                else next_state = S_IF2;
            end
            S_ID_EXE: begin
                if (we_mem || re_mem) begin
                    if ((re_mem && dmem_ift.r_request_ready) || (we_mem && dmem_ift.w_request_ready))
                        next_state = S_MEM;
                    else
                        next_state = S_ID_EXE;
                end else begin
                    next_state = S_IF1;
                end
            end
            S_MEM: begin
                if ((re_mem && dmem_ift.r_reply_valid && dmem_ift.r_reply_ready) ||
                    (we_mem && dmem_ift.w_reply_valid && dmem_ift.w_reply_ready))
                    next_state = S_IF1;
                else next_state = S_MEM;
            end
            default: next_state = S_IF1;
        endcase
    end

    assign imem_ift.r_request_valid = (state == S_IF1);
    assign imem_ift.r_reply_ready   = (state == S_IF2);
    assign imem_ift.w_request_valid = 1'b0;
    assign imem_ift.w_request_bits.waddr = 64'b0;
    assign imem_ift.w_request_bits.wdata = 64'b0;
    assign imem_ift.w_request_bits.wmask = 8'b0;
    assign imem_ift.w_reply_ready   = 1'b0;

    assign dmem_ift.r_request_valid = (state == S_ID_EXE && re_mem);
    assign dmem_ift.w_request_valid = (state == S_ID_EXE && we_mem);
    assign dmem_ift.r_reply_ready   = (state == S_MEM && re_mem);
    assign dmem_ift.w_reply_ready   = (state == S_MEM && we_mem);
    
    assign dmem_ift.r_request_bits.raddr = alu_res;
    assign dmem_ift.w_request_bits.waddr = alu_res;
    assign dmem_ift.w_request_bits.wdata = data_package;
    assign dmem_ift.w_request_bits.wmask = mask_package;
    
    assign imem_ift.r_request_bits.raddr = pc;

    assign inst_en = (state == S_IF2 && imem_ift.r_reply_valid);
    
    assign cosim_valid = (state == S_ID_EXE && !we_mem && !re_mem) ||
                         (state == S_MEM && ( (re_mem && dmem_ift.r_reply_valid) || (we_mem && dmem_ift.w_reply_valid) ));
                         
    assign stall = !cosim_valid;

endmodule