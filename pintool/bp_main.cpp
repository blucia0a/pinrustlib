#include <pin.H>

#include <cmath>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <string>
#include <vector>

extern "C" void run (unsigned long);
void branch(ADDRINT pc) {

  run(pc);

}

void InstrumentInstruction(INS ins, void *v) {
  if (INS_IsBranch(ins) && INS_HasFallThrough(ins)) {
    INS_InsertCall(ins, IPOINT_BEFORE, (AFUNPTR) branch,
        IARG_INST_PTR, IARG_BRANCH_TAKEN, IARG_END);
  }
}

void Finished(int code, void *v) {
}

int main(int argc, char *argv[]) {

  PIN_Init(argc, argv);

  INS_AddInstrumentFunction(InstrumentInstruction, 0);
  PIN_AddFiniFunction(Finished, 0);

  PIN_StartProgram();

  return 0;
}
