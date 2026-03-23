`include "core_struct.vh"
`include "csr_struct.vh"

module CSR_ALU (
    input CorePack::data_t a,
    input CorePack::data_t b,
    input CsrPack::csr_alu_op_enmu alu_op,
    output CorePack::data_t res
);

    import CsrPack::*;

    always_comb begin
        case(alu_op)
            CSR_ALU_ADD:    res = a; // csrrw: just pass the source (rs1 or imm)
            CSR_ALU_OR:     res = a | b; // csrrs: a is rs1/imm, b is csr_val
            CSR_ALU_ANDNOT: res = (~a) & b; // csrrc: a is rs1/imm, b is csr_val
            default:        res = a;
        endcase
    end

endmodule