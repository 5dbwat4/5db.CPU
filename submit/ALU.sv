`include "core_struct.vh"
module ALU (
    input  CorePack::data_t a,
    input  CorePack::data_t b,
    input  CorePack::alu_op_enum  alu_op,
    output CorePack::data_t res
);

import CorePack::*;

logic [31:0] addw_res;
logic [31:0] subw_res;
logic [31:0] sllw_res;
logic [31:0] srlw_res;
logic [31:0] sraw_res;

assign addw_res = a[31:0] + b[31:0];
assign subw_res = a[31:0] - b[31:0];
assign sllw_res = a[31:0] << b[4:0];
assign srlw_res = a[31:0] >> b[4:0];
assign sraw_res = $signed(a[31:0]) >>> b[4:0];

always_comb begin
    case(alu_op)
        ALU_ADD:  res = a + b;
        ALU_SUB:  res = a - b;
        ALU_AND:  res = a & b;
        ALU_OR:   res = a | b;
        ALU_XOR:  res = a ^ b;
        ALU_SLT:  res = $signed(a) < $signed(b) ? 64'b1 : 64'b0;
        ALU_SLTU: res = a < b ? 64'b1 : 64'b0;
        ALU_SLL:  res = a << b[5:0];
        ALU_SRL:  res = a >> b[5:0];
        ALU_SRA:  res = $signed(a) >>> b[5:0];
        ALU_ADDW: res = {{32{addw_res[31]}}, addw_res};
        ALU_SUBW: res = {{32{subw_res[31]}}, subw_res};
        ALU_SLLW: res = {{32{sllw_res[31]}}, sllw_res};
        ALU_SRLW: res = {{32{srlw_res[31]}}, srlw_res};
        ALU_SRAW: res = {{32{sraw_res[31]}}, sraw_res};
        default:  res = 64'b0;
    endcase
end

endmodule