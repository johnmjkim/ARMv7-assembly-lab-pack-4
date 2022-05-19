#include <stdio.h>

int addThreeNumbers( int a, int b, int c )
{
    int sum =0;
    sum += a;
    sum += b;
    sum += c;
    return sum;
}

int main(void)
{
  int a = 3;
  int b = 4;
  int c = 7;
  int sum = addThreeNumbers(a, b, c);

  return 0;
}
