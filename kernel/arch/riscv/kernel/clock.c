#include <stdint.h>
#include <private_kdefs.h>
#include <sbi.h>
#include <printk.h>
#include <print.h>


uint64_t global_expected_time = 0;

// void clock_set_next_event(void) {
//   uint64_t time;

//   // 1. 使用 rdtime 指令读取当前时间
//   __asm__ volatile("rdtime %0" : "=r"(time));
//   // printk("[Clock] Current time read as %llu; delay %llu\n", (unsigned long long)time, (unsigned long long)time-global_expected_time);



//   // 2. 计算下一次中断的时间
//   global_expected_time = global_expected_time + TIMECLOCK;


//   // 3. 调用 sbi_set_timer 设置下一次时钟中断
//   sbi_ecall(0x54494D45 , 0, global_expected_time, 0, 0, 0, 0, 0);
//   // printk("[Clock] Next timer event set for %llu\n", (unsigned long long)global_expected_time);
// }

void clock_set_next_event(void) {
  sbi_ecall(0x54494d45, 0, TIMECLOCK, 0, 0, 0, 0, 0);
}

// void timer_init(void) {
//   /* schedule first timer interrupt */
//   clock_set_next_event();

//   /* enable global machine interrupts (MSTATUS.MIE) */
//   const unsigned long MSTATUS_MIE = 1UL << 3;
//   __asm__ volatile("csrrs x0, mstatus, %0" :: "r"(MSTATUS_MIE));

//   /* enable machine timer interrupts (MIE.MTIE) */
//   const unsigned long MIE_MTIE = 1UL << 7;
//   __asm__ volatile("csrrs x0, mie, %0" :: "r"(MIE_MTIE));
// }