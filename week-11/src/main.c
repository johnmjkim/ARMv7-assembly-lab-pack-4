#include <stdio.h>

void square(int *p)
{
    int val = *p;
    val = val*val;
    *p = val;
}

int main(void)
{
  int x = 3;
  int *p = &x;
  square(p);

  return 0;
}
