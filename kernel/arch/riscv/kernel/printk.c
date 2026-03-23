#include <stdio.h>
#include <printk.h>
#include <sbi.h>
#include <stdint.h>
#include <stdarg.h>

#define bool int
#define true 1
#define false 0

#if UINTPTR_MAX > 0xFFFFFFFFu
#define LOBYTE(p) ((uint64_t)((uintptr_t)(p) & 0xFFFFFFFFu))
#define HIBYTE(p) ((uint64_t)(((uintptr_t)(p) >> 32) & 0xFFFFFFFFu))
#else
#define LOBYTE(p) ((uint64_t)((uintptr_t)(p)))
#define HIBYTE(p) ((uint64_t)0)
#endif

static int printk_sbi_write(FILE *restrict fp, const void *restrict buf, size_t len) {
  (void)fp;
  struct sbiret ret = sbi_ecall(SBI_DEBUG_CONSOLE_EXTENSION_ID, 0, (uint64_t)len, LOBYTE(buf), HIBYTE(buf), 0, 0, 0);
  if (ret.error) {
    return 0;
  }
  return ret.value;
}

// static size_t strlen_kernel(const char *s) {
//   size_t len = 0;
//   while (s[len] != '\0') {
//     len++;
//   }
//   return len;
// }

// static int printk_buf_write(FILE *restrict fp, const void *restrict buf, size_t len) {
//   // Directly forward to SBI write without buffering
//   return printk_sbi_write(fp, buf, len);
// }

// static int printk_flush(FILE *restrict fp) {
//   (void)fp;
//   // no-op since writes are direct
//   return 0;
// }

void printk(const char *fmt, ...) {
  FILE printk_out = {
      .write = printk_sbi_write,
  };

  va_list ap;
  va_start(ap, fmt);
  vfprintf(&printk_out, fmt, ap);
  va_end(ap);
  // nothing to flush
}
