#!/bin/sh
nvcc -std=c++17 -DNVCC_ARCH_NUM=52 -c tests/test_arch_define.cu -o /tmp/test_arch_define.o && echo "arch define test passed"
