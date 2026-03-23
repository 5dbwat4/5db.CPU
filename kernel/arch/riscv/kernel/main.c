#include <printk.h>
#include <print.h>
#include <sbi.h>

#include <private_kdefs.h>

// _Noreturn static void test(void) __attribute__((noinline));
// _Noreturn static void test(void) {
//   uint64_t last_timeval = 0;
//   uint64_t time = 0;

//   while (1) {
//     uint64_t timeval;
//     asm volatile("rdtime %0" : "=r"(timeval));
//     asm volatile("rdtime %0" : "=r"(time));
//     timeval /= 60000;
//     if (timeval != last_timeval) {
//       last_timeval = timeval;
//       uint64_t before_printk_time;
//       asm volatile("rdtime %0" : "=r"(before_printk_time));
//       printk("Kernel is running! timeval = %" PRIu64 "; time = %" PRIu64 "\n", timeval, time);
//       uint64_t after_printk_time;
//       asm volatile("rdtime %0" : "=r"(after_printk_time));
//       printk("printk took %" PRIu64 " cycles\n", after_printk_time - before_printk_time);
//     }
//   }
//   // while (1) {
//   //     uint64_t time0;
//   //     asm volatile("rdtime %0" : "=r"(time0));
//   //     for (volatile int j = 0; j < 100; j++)
//   //     printk("123456789098765432123456789876543212345678987654\r", time0);
//   //     uint64_t time1;
//   //     asm volatile("rdtime %0" : "=r"(time1));
//   //     printk("\ntime = %" PRIu64 "\n", time1-time0  );
//   // }
// }

// _Noreturn void start_kernel(void) {
//   csr_write(sscratch, 0x7e9);
//   puti(csr_read(sscratch));
//   puts(" ZJU Computer System II \n");

//   ecall_test();
// }
// _Noreturn void start_kernel() {
//   csr_write(sscratch, 0x7e9);
  
  
//   puts(" ZJU Computer System II \n");

//   test();
// }

// #include <printk.h>

_Noreturn void start_kernel(void) {
  printk("2025 ZJU Computer System II\n");

  // 等待第一次时钟中断
  while (1)
    ;
}