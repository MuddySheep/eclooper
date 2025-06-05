#!/bin/sh
cc -O3 -ffast-math -Wall -Wextra -Werror=restrict -D_FORTIFY_SOURCE=2 tests/test_fe_clone.c -o tests/test_fe_clone && ./tests/test_fe_clone && echo "fe_clone test passed"
