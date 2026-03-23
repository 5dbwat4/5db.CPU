`include "core_struct.vh"

module ImmGen (
    input CorePack::inst_t inst,
    input CorePack::imm_op_enum imm_op,
    output CorePack::data_t imm
);

import CorePack::*;

always_comb begin
    case(imm_op)
        I_IMM:  imm = {{52{inst[31]}}, inst[31:20]};
        S_IMM:  imm = {{52{inst[31]}}, inst[31:25], inst[11:7]};
        B_IMM:  imm = {{52{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
        U_IMM:  imm = {{32{inst[31]}}, inst[31:12], 12'b0};
        UJ_IMM: imm = {{44{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
        default: imm = 64'b0;
    endcase
end

endmodule