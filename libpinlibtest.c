#include <stdio.h>

extern "C" void rust_run(unsigned long);
extern "C" void run(unsigned long addr){
  rust_run(addr);
}
