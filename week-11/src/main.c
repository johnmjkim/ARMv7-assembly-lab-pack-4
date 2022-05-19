#include <stdio.h>

int main(void)
{
  // set P0.21 (ROW 1) and P0.28 (COL1) as OUTPUT
  volatile int *GPIO_P0_DIR = (int*) 0x50000514;
  *GPIO_P0_DIR = *GPIO_P0_DIR | (0x1 << 21);
  *GPIO_P0_DIR = *GPIO_P0_DIR | (0x1 << 28);

  // set P0.21 (ROW 1) output as HIGH
  volatile int *GPIO_P0_OUT = (int*) 0x50000504;
  *GPIO_P0_OUT = *GPIO_P0_OUT | (0x1 << 21);

  return 0;
}
