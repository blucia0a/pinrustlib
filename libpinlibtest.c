#include <stdio.h>
#include <stddef.h>

extern "C" unsigned long rust_run(unsigned long);
extern "C" void run(unsigned long addr){
  fprintf(stderr, "addr = %lx\n",addr);
  unsigned long res = rust_run(addr);
  fprintf(stderr, "addr+1 = %lx\n",res);
}

extern "C" int bcmp(const void *b1, const void *b2, size_t length)
{
	char *p1, *p2;

	if (length == 0)
		return(0);
	p1 = (char *)b1;
	p2 = (char *)b2;
	do
		if (*p1++ != *p2++)
			break;
	while (--length);
	return(length);
}
