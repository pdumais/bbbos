#include "swi.h"
#include "mcp23s18.h"

#define push(a...) stmdb r13!,{a}
#define pop(a...) ldmia r13!,{a}

