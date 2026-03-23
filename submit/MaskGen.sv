`include "core_struct.vh"

module MaskGen(
    input CorePack::mem_op_enum mem_op,
    input CorePack::addr_t dmem_waddr,
    output CorePack::mask_t dmem_wmask
);

import CorePack::*;

logic [2:0] offset;
assign offset = dmem_waddr[2:0];

always_comb begin
    case(mem_op)
        MEM_B, MEM_UB: dmem_wmask = 8'b0000_0001 << offset;
        MEM_H, MEM_UH: dmem_wmask = 8'b0000_0011 << offset;
        MEM_W, MEM_UW: dmem_wmask = 8'b0000_1111 << offset;
        MEM_D: dmem_wmask = 8'b1111_1111;
        default: dmem_wmask = 8'b0;
    endcase
end

endmodule