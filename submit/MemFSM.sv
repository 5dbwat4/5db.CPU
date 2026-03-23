`include "core_struct.vh"

module MemFSM (
    input clk,
    input rst,

    Mem_ift.Master imem_ift,
    Mem_ift.Master dmem_ift,

    input logic re_mem_MEM,
    input logic we_mem_MEM,
    input logic valid_MEM,

    output logic mem_stall,
    output logic if_stall
);

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

    assign mem_stall = mem_req && !(state == MEM2 && d_rep_done);
    assign if_stall = !( (state == IF2 && i_rep_done) || (state == WAITFOR2 && i_rep_done) );

endmodule