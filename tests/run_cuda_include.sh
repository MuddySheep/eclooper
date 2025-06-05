#!/bin/sh
cc -DWITH_CUDA tests/test_cuda_include.c -o tests/test_cuda_include && echo "cuda include test passed"
