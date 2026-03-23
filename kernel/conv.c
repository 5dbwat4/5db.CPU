#include "conv.h"
#include "uart.h"
void print_str(const char* str);
void print_hex(uint64_t data);
void print_array(const uint64_t* array, size_t len);

typedef unsigned long long int size_t;
uint64_t* CONV_BASE = (uint64_t*)0x10001000L;
const size_t CONV_KERNEL_OFFSET = 0;
const size_t CONV_DATA_OFFSET = 1;
const size_t CONV_RESULT_LO_OFFSET = 0;
const size_t CONV_RESULT_HI_OFFSET = 1;
const size_t CONV_STATE_OFFSET = 2;
const unsigned char READY_MASK = 0b01;
const size_t CONV_ELEMENT_LEN = 4;

uint64_t* MISC_BASE = (uint64_t*)0x10002000L;
const size_t MISC_TIME_OFFSET = 0;

uint64_t get_time(void){
    return MISC_BASE[MISC_TIME_OFFSET];
}


void conv_kernel_init(const uint64_t* kernel_array, size_t kernel_len) {
    for (size_t i = 0; i < kernel_len; i++) {
        *(CONV_BASE + CONV_KERNEL_OFFSET) = kernel_array[i];
    }
}

// 计算单个字节的卷积
void conv_compute_one_byte(uint64_t data, uint64_t* result_hi, uint64_t* result_lo) {
    *(CONV_BASE + CONV_DATA_OFFSET) = data;
    while ((*(CONV_BASE + CONV_STATE_OFFSET) & READY_MASK) == 0);
    *result_lo = *(CONV_BASE + CONV_RESULT_LO_OFFSET);
    *result_hi = *(CONV_BASE + CONV_RESULT_HI_OFFSET);
}

void conv_compute(const uint64_t* data_array, size_t data_len, 
	const uint64_t* kernel_array, size_t kernel_len, uint64_t* dest){
    conv_kernel_init(kernel_array, kernel_len);
    for (size_t i = 0; i < kernel_len-1; i++) {
        conv_compute_one_byte(0, 0, 0);
    }
    for (size_t i = 0; i < data_len; i++) {
        uint64_t data;
        data = data_array[i];
        uint64_t result_hi, result_lo;
        conv_compute_one_byte(data, &result_hi, &result_lo);

        dest[i << 1] = result_hi;      
        dest[(i << 1) + 1] = result_lo;
    }
    for (size_t i = data_len; i < data_len+kernel_len-1; i++) {

        uint64_t result_hi, result_lo;
        conv_compute_one_byte(0, &result_hi, &result_lo);

        dest[i << 1] = result_hi;       
        dest[(i << 1) + 1] = result_lo; 
    }
}

// void add_128(uint64_t a_hi, uint64_t a_lo, uint64_t b_hi, uint64_t b_lo, uint64_t* result_hi, uint64_t* result_lo) {
//     uint64_t lo = a_lo + b_lo;
//     uint64_t carry = (lo < a_lo) ? 1ULL : 0ULL;
//     uint64_t hi = a_hi + b_hi + carry;
//     *result_hi = hi;
//     *result_lo = lo;
// }

// // 辅助函数：128 位乘法（不使用乘法运算，采用移位加法）
// void mul_128(uint64_t a, uint64_t b, uint64_t* result_hi, uint64_t* result_lo) {
//     uint64_t res_hi = 0;
//     uint64_t res_lo = 0;

//     uint64_t cur_hi = 0;
//     uint64_t cur_lo = a;

//     uint64_t bb = b;
//     while (bb) {
//         // use add_128 to add cur to res if the lowest bit of bb is 1
//         if (bb & 1) {
//             uint64_t new_res_hi, new_res_lo;
//             add_128(res_hi, res_lo, cur_hi, cur_lo, &new_res_hi, &new_res_lo);
//             res_hi = new_res_hi;
//             res_lo = new_res_lo;
//         }
//         // shift cur left by 1
//         uint64_t new_cur_hi = (cur_hi << 1) | (cur_lo >> 63);
//         uint64_t new_cur_lo = cur_lo << 1;
//         cur_hi = new_cur_hi;
//         cur_lo = new_cur_lo;
//         // shift bb right by 1
//         bb >>= 1;
//     }

//     *result_hi = res_hi;
//     *result_lo = res_lo;
//     return;
// }

// void mul_compute(const uint64_t* data_array, size_t data_len, const uint64_t* kernel_array, size_t kernel_len, uint64_t* dest){
//     // 计算卷积次数：padding 前后各3个0，卷积输出位置为 data_len + 3
//     size_t conv_times = data_len + 3;
    
//     // 对每个卷积位置进行计算
//     for (size_t i = 0; i < conv_times; i++) {
//         uint64_t sum_hi = 0;
//         uint64_t sum_lo = 0;
        
//         // 卷积计算：data[i] * kernel[0] + data[i+1] * kernel[1] + ...
//         for (size_t j = 0; j < kernel_len; j++) {
//             size_t data_index = i + j;
//             uint64_t data_val;
            
//             // 处理边界条件：前后填充0
//             if (data_index < 3 || data_index >= data_len + 3) {
//                 data_val = 0;
//             } else {
//                 data_val = data_array[data_index - 3];
//             }
            
//             // 计算乘法结果（使用移位加法实现的 64x64 -> 128 乘法）
//             uint64_t mul_hi, mul_lo;
//             mul_128(data_val, kernel_array[j], &mul_hi, &mul_lo);
            
//             // 累加到总和（128 位加法）
//             uint64_t new_sum_hi, new_sum_lo;
//             add_128(sum_hi, sum_lo, mul_hi, mul_lo, &new_sum_hi, &new_sum_lo);
//             sum_hi = new_sum_hi;
//             sum_lo = new_sum_lo;
//         }
        
//         // 存储结果：dest 以 128 位宽度存放，高位在前，低位在后
//         dest[i << 1] = sum_hi;        // 高64位
//         dest[(i << 1) + 1] = sum_lo;  // 低64位
//     }
// }

// #include <stdint.h>
// #include <stddef.h>


void add_128(uint64_t a_hi, uint64_t a_lo, uint64_t b_hi, uint64_t b_lo, uint64_t* result_hi, uint64_t* result_lo) {
    uint64_t lo = a_lo + b_lo;
    uint64_t carry = (lo < a_lo) ? 1ULL : 0ULL;
    uint64_t hi = a_hi + b_hi + carry;
    *result_hi = hi;
    *result_lo = lo;
}

void mul_128(const uint64_t a, const uint64_t b, uint64_t* result_hi, uint64_t* result_lo) {
    uint64_t res_hi = 0;
    uint64_t res_lo = 0;

    uint64_t cur_hi = 0;
    uint64_t cur_lo = a;

    uint64_t bb = b;
    while (bb) {
        // use add_128 to add cur to res if the lowest bit of bb is 1
        if (bb & 1) {
            uint64_t new_res_hi, new_res_lo;
            add_128(res_hi, res_lo, cur_hi, cur_lo, &new_res_hi, &new_res_lo);
            res_hi = new_res_hi;
            res_lo = new_res_lo;
        }
        // shift cur left by 1
        uint64_t new_cur_hi = (cur_hi << 1) | (cur_lo >> 63);
        uint64_t new_cur_lo = cur_lo << 1;
        cur_hi = new_cur_hi;
        cur_lo = new_cur_lo;
        // shift bb right by 1
        bb >>= 1;
    }
    *result_hi = res_hi;
    *result_lo = res_lo;
}

void mul_compute(const uint64_t* data_array, size_t data_len, 
          const uint64_t* kernel_array, size_t kernel_len, 
          uint64_t* dest) {

    
    for (size_t i = 0; i < data_len+2*(kernel_len-1); i++) {
        uint64_t sum_hi = 0;
        uint64_t sum_lo = 0;

        for (size_t j = 0; j < kernel_len; j++) {
            if(j > i) {
                continue;
            }
            if(i - j >= data_len) {
                continue;
            }
            size_t data_index = i - j;
            uint64_t data = data_array[data_index];
            uint64_t kernel_val = kernel_array[kernel_len-j-1];
            // printf("data_index: %zu, data: %016llx, kernel_val: %016llx\n", data_index, data, kernel_val);

            uint64_t mul_hi = 0;
            uint64_t mul_lo = 0;
            mul_128(data, kernel_val, &mul_hi, &mul_lo);
            print_str("ttx:");
            print_hex(mul_hi);
            uart_tx(',');
            print_hex(mul_lo);
            uart_tx('\n');
            // printf("mul_hi: %016llx, mul_lo: %016llx\n", mul_hi, mul_lo);
            
            // 累加到总和
            add_128(sum_hi, sum_lo, mul_hi, mul_lo, &sum_hi, &sum_lo);
            print_str("sum:");
            print_hex(sum_hi);
            uart_tx(',');
            print_hex(sum_lo);
            uart_tx('\n');
        }
        dest[i << 1] = sum_hi;
        dest[(i << 1) + 1] = sum_lo;
        print_str("commit");
        print_hex((uint64_t)i);
        uart_tx(':');
        print_hex(sum_hi);
        uart_tx(',');
        print_hex(sum_lo);
        uart_tx('|');
        print_hex(dest[i << 1]);
        uart_tx(',');
        print_hex(dest[(i << 1) + 1]);

        
    }
}
