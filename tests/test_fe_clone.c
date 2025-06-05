#include "../lib/ecc.c"
int main() {
  fe a = {1, 2, 3, 4};
  fe_clone(a, a); // self-copy should be no-op
  if (a[0] != 1 || a[1] != 2 || a[2] != 3 || a[3] != 4) {
    return 1;
  }
  fe b;
  fe_clone(b, a);
  for (int i = 0; i < 4; ++i)
    if (b[i] != a[i]) return 1;
  return 0;
}
