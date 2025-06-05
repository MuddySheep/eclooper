#pragma once
#include <stdint.h>

static const union { uint32_t i; uint8_t c[4]; } _ecl_endian_test = {1};
#define IS_LITTLE_ENDIAN (_ecl_endian_test.c[0] == 1)

