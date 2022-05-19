#include <stdio.h>

struct student {
  int uid;
  float score;
  char firstname[20];
  char lastname[20];
};

void cheating(struct student *stu_ptr)
{
  stu_ptr->score = 110;
  char *p = stu_ptr->lastname;
  p[0] = 'X';
}

int main(void)
{
  struct student full = {1234567, 77.6, "first", "last"};
  struct student *stu_ptr = &full;
  cheating(stu_ptr);
  
  return 0;
}
