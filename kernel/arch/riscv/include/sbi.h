#ifndef __SBI_H__
#define __SBI_H__

#define SBI_CONSOLE_PUTCHAR 2
#define SBI_DEBUG_CONSOLE_EXTENSION_ID 	0x4442434e	// "DBCN" 

#include <stdint.h>

#define csr_read(csr)                                    \
  ({                                                     \
    uint64_t __v;                                        \
    asm volatile("csrr %0, " #csr : "=r"(__v));          \
    __v;                                                 \
  })

#define csr_write(csr, val)                                    \
  ({                                                           \
    uint64_t __v = (uint64_t)(val);                            \
    asm volatile("csrw " #csr ", %0" : : "r"(__v) : "memory"); \
  })

struct sbiret {
  uint64_t error;
  uint64_t value;
};

struct sbiret sbi_ecall(uint64_t eid, uint64_t fid,
                        uint64_t arg0, uint64_t arg1, uint64_t arg2,
                        uint64_t arg3, uint64_t arg4, uint64_t arg5);
#endif
