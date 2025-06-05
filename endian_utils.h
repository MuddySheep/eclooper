#pragma once
#include <stdint.h>
#include <assert.h>

#if defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__)
#define IS_LITTLE_ENDIAN (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#else
#include <endian.h>
#define IS_LITTLE_ENDIAN (__BYTE_ORDER == __LITTLE_ENDIAN)
#endif

static_assert(IS_LITTLE_ENDIAN, "ecloop requires little-endian");

