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
    
    // PC
    addr_t pc;
    addr_t next_pc;

    // IF stage
    assign imem_ift.r_request_valid = 1'b1;
    assign imem_ift.r_request_bits.raddr = pc;
    assign imem_ift.w_request_valid = 1'b0;
    assign imem_ift.w_request_bits.waddr = 64'b0;
    assign imem_ift.w_request_bits.wdata = 64'b0;
    assign imem_ift.w_request_bits.wmask = 8'b0;
    
    inst_t inst;
    assign inst = pc[2] ? imem_ift.r_reply_bits.rdata[63:32] : imem_ift.r_reply_bits.rdata[31:0];

    // Decode
    logic we_reg;
    logic we_mem;
    logic re_mem;
    logic npc_sel;
    imm_op_enum immgen_op;
    alu_op_enum alu_op;
    cmp_op_enum cmp_op;
    alu_asel_op_enum alu_asel;
    alu_bsel_op_enum alu_bsel;
    wb_sel_op_enum wb_sel;
    mem_op_enum mem_op;

    controller ctrl (
        .inst(inst),
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
        .inst(inst),
        .imm_op(immgen_op),
        .imm(imm)
    );

    // Register file
    reg_ind_t rs1;
    reg_ind_t rs2;
    reg_ind_t rd;
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd = inst[11:7];

    data_t read_data_1;
    data_t read_data_2;
    data_t wb_val;

    RegFile reg_file_inst (
        .clk(clk),
        .rst(rst),
        .we(we_reg),
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
    assign br_taken = (inst[6:0] == BRANCH_OPCODE) ? cmp_res : 1'b0;
    
    addr_t pc_plus_4;
    assign pc_plus_4 = pc + 4;
    
    always_comb begin
        if (inst[6:0] == JALR_OPCODE) begin
            next_pc = (alu_res) & ~64'b1;
        end else if (br_taken || inst[6:0] == JAL_OPCODE) begin
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

    assign dmem_ift.r_request_valid = re_mem;
    assign dmem_ift.r_request_bits.raddr = alu_res;

    assign dmem_ift.w_request_valid = we_mem;
    assign dmem_ift.w_request_bits.waddr = alu_res;
    assign dmem_ift.w_request_bits.wdata = dmem_wdata;
    assign dmem_ift.w_request_bits.wmask = dmem_wmask;

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

    // PC Update
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 64'h0;
        end else begin
            pc <= next_pc;
        end
    end

    assign cosim_valid = 1'b1;
    assign cosim_core_info.pc        = pc;
    assign cosim_core_info.inst      = {32'b0,inst};   
    assign cosim_core_info.rs1_id    = {59'b0, rs1};
    assign cosim_core_info.rs1_data  = read_data_1;
    assign cosim_core_info.rs2_id    = {59'b0, rs2};
    assign cosim_core_info.rs2_data  = read_data_2;
    assign cosim_core_info.alu       = alu_res;
    assign cosim_core_info.mem_addr  = dmem_ift.r_request_bits.raddr;
    assign cosim_core_info.mem_we    = {63'b0, dmem_ift.w_request_valid};
    assign cosim_core_info.mem_wdata = dmem_ift.w_request_bits.wdata;
    assign cosim_core_info.mem_rdata = dmem_ift.r_reply_bits.rdata;
    assign cosim_core_info.rd_we     = {63'b0, we_reg};
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
    output logic stall
);
    import CorePack::*;

    assign stall = 1'b0;

endmodule