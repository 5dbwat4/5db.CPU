#include <stdint.h>
#include <proc.h>

// 时钟中断相关函数声明
void clock_set_next_event(void);

// 简单的打印函数声明（假设已经实现）
void printk(const char *format, ...);

// 定义中断/异常原因
#define INTERRUPT_MASK (1UL << 63)  // 最高位表示中断(1)还是异常(0)
#define INTERRUPT_CODE_MASK 0x7FFFFFFFFFFFFFFFUL  // 低63位表示中断/异常代码

// Supervisor Timer Interrupt 的代码
#define SUPERVISOR_TIMER_INTERRUPT 5

void trap_handler(uint64_t scause, uint64_t sepc) {
    // 判断是否是中断（最高位为1）
    if (scause & INTERRUPT_MASK) {
        // 提取中断代码（清除最高位）
        uint64_t interrupt_code = scause & INTERRUPT_CODE_MASK;
        
        // 判断是否是 Supervisor Timer Interrupt
        if (interrupt_code == SUPERVISOR_TIMER_INTERRUPT) {
            // 打印输出相关信息
            // printk("[Trap Handler] Supervisor Timer Interrupt at sepc: 0x%llx\n", sepc);
            
            // 调用 clock_set_next_event 设置下一次时钟中断
            clock_set_next_event();
            do_timer();  // 调用时钟中断处理函数
        } else {
            // 处理其他类型的中断（可选）
            printk("[Trap Handler] Unknown interrupt: scause=0x%llx, sepc=0x%llx\n", 
                   scause, sepc);
        }
    } else {
        // 处理异常（最高位为0）
        printk("[Trap Handler] Exception occurred: scause=0x%llx, sepc=0x%llx\n", 
               scause, sepc);
        
        // 这里可以添加更多异常处理逻辑
        // 例如：根据scause的值判断异常类型并进行相应处理
        uint64_t exception_code = scause;
        
        switch (exception_code) {
            case 0:  // Instruction address misaligned
                printk("Instruction address misaligned\n");
                break;
            case 1:  // Instruction access fault
                printk("Instruction access fault\n");
                break;
            case 2:  // Illegal instruction
                printk("Illegal instruction\n");
                break;
            case 3:  // Breakpoint
                printk("Breakpoint\n");
                break;
            case 4:  // Load address misaligned
                printk("Load address misaligned\n");
                break;
            case 5:  // Load access fault
                printk("Load access fault\n");
                break;
            case 6:  // Store/AMO address misaligned
                printk("Store/AMO address misaligned\n");
                break;
            case 7:  // Store/AMO access fault
                printk("Store/AMO access fault\n");
                break;
            case 8:  // Environment call from U-mode
                printk("Environment call from U-mode\n");
                break;
            case 9:  // Environment call from S-mode
                printk("Environment call from S-mode\n");
                break;
            case 11: // Environment call from M-mode
                printk("Environment call from M-mode\n");
                break;
            default:
                printk("Unknown exception code: %llu\n", exception_code);
                break;
        }
    }
}