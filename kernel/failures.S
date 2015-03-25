#include "macros.h"

.global failFromInterrupt

failInterruptBottom:
.skip 128
failInterruptTop:


failFromInterrupt:

    mrs     r0,SPSR
    orr     r0,r0,#0b11111
    msr     CPSR,r0
   // maybe we are failing because the stack is screwed up, so reset it  
    ldr     r13,=failInterruptTop
    PRINTK("Process failed\r\n")

1:  b       1b      // spin wait

