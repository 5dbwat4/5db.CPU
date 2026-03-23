`include "core_struct.vh"

module DataPkg(
    input CorePack::mem_op_enum mem_op,
    input CorePack::data_t reg_data,
    input CorePack::addr_t dmem_waddr,
    output CorePack::data_t dmem_wdata
);

import CorePack::*;

logic [5:0] shift;
assign shift = {dmem_waddr[2:0], 3'b000}; // dmem_waddr % 8 * 8

always_comb begin
    case(mem_op)
        MEM_B, MEM_UB: dmem_wdata = (reg_data & 64'hFF) << shift;
        MEM_H, MEM_UH: dmem_wdata = (reg_data & 64'hFFFF) << shift;
        MEM_W, MEM_UW: dmem_wdata = (reg_data & 64'hFFFF_FFFF) << shift;
        MEM_D: dmem_wdata = reg_data; // shift is 0 because double word is 8-byte aligned
        default: dmem_wdata = 64'b0;
    endcase
end

endmodule