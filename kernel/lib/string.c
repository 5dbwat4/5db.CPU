#include <string.h>

// void *memset(void *restrict dst, int c, size_t n) {
// #error Not yet implemented
// }

// size_t strnlen(const char *restrict s, size_t maxlen) {
// #error Not yet implemented
// }

#define OPSIZ (sizeof (op_t))
typedef unsigned long int op_t;
typedef unsigned char byte;

void *
memset (void *dstpp, int c, size_t len)
{
  long int dstp = (long int) dstpp;

  if (len >= 8)
    {
      size_t xlen;
      op_t cccc;

      cccc = (unsigned char) c;
      cccc |= cccc << 8;
      cccc |= cccc << 16;
      if (OPSIZ > 4)
        /* Do the shift in two steps to avoid warning if long has 32 bits.  */
        cccc |= (cccc << 16) << 16;

      /* There are at least some bytes to set.
         No need to test for LEN == 0 in this alignment loop.  */
      while (dstp % OPSIZ != 0)
        {
          ((byte *) dstp)[0] = c;
          dstp += 1;
          len -= 1;
        }

      /* Write 8 `op_t' per iteration until less than 8 `op_t' remain.  */
      xlen = len / (OPSIZ * 8);
      while (xlen > 0)
        {
          ((op_t *) dstp)[0] = cccc;
          ((op_t *) dstp)[1] = cccc;
          ((op_t *) dstp)[2] = cccc;
          ((op_t *) dstp)[3] = cccc;
          ((op_t *) dstp)[4] = cccc;
          ((op_t *) dstp)[5] = cccc;
          ((op_t *) dstp)[6] = cccc;
          ((op_t *) dstp)[7] = cccc;
          dstp += 8 * OPSIZ;
          xlen -= 1;
        }
      len %= OPSIZ * 8;

      /* Write 1 `op_t' per iteration until less than OPSIZ bytes remain.  */
      xlen = len / OPSIZ;
      while (xlen > 0)
        {
          ((op_t *) dstp)[0] = cccc;
          dstp += OPSIZ;
          xlen -= 1;
        }
      len %= OPSIZ;
    }

  /* Write the last few bytes.  */
  while (len > 0)
    {
      ((byte *) dstp)[0] = c;
      dstp += 1;
      len -= 1;
    }

  return dstpp;
}

void * memchr (const void *s, int c, size_t n)
{
  const unsigned char *p = s;
  unsigned char ch = c;

  for (; n > 0; n--, p++)
    {
      if (*p == ch)
        return (void *) p;
    }
  return NULL;
}

size_t
strnlen (const char *str, size_t maxlen)
{
  const char *found = memchr (str, '\0', maxlen);
  return found ? found - str : maxlen;
}