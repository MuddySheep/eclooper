#pragma once
#include <stdint.h>

typedef unsigned long long u64;
typedef unsigned int u32;
typedef unsigned char u8;

typedef u64 fe[4];
#ifndef PE_DEFINED
typedef struct pe {
  fe x, y, z;
} pe;
#define PE_DEFINED
#endif

#ifdef __cplusplus
extern "C" {
#endif

void ec_jacobi_mulrdc_cuda(pe *r, const pe *p, const fe k);

#ifdef __cplusplus
}
#endif
