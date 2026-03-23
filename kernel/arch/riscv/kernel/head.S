#include "private_kdefs.h"

    .section .text.init
    .globl _start
_start:
    # 0. 设置 sp 为 _ekernel 之后 4 KiB 的位置
    la sp, _sbss

    # 1. 将 stvec 设置为 _traps
    la t0, _traps
    csrw stvec, t0

    # 2. 设置 sie[STIE]
    csrr t0, sie
    ori t0, t0, 0x20      # STIE 是第 5 位 (1 << 5 = 0x20)
    csrw sie, t0

    call mm_init

    # 3. 设置第一次时钟中断的时间
    call clock_set_next_event

    # 4. 设置 sstatus[SIE]
    csrr t0, sstatus
    ori t0, t0, 0x02      # SIE 是第 1 位 (1 << 1 = 0x02)
    csrw sstatus, t0

    # 5. 跳转到 start_kernel
    call task_init
    j start_kernel

    .section .bss.stack
    .space PGSIZE