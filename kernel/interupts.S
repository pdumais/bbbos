#include "macros.h"
#include "definitions.h"
#include "interupts.h"

.global int_undefined
.global int_IRQ
.global initINTC
.global enableInterrupt
.global returnFromInterrupt
.global generate_SGI
.global is_SGI
.global irq_invoke_soft_handler
.global irq_add_soft_handler

#define SYSCONFIG 0x10
#define SYSSTATUS 0x14
#define SIR_IRQ 0x40
#define MIR_CLEAR 0x88
#define ISR_SET 0x90
#define ISR_CLEAR 0x94
#define CONTROL 0x48


initINTC:
    push(r0-r3,r14)

    // clear the handler table
    ldr     r0,=handlers
    mov     r1,#0
    mov     r2,#0
1:  str     r1,[r0],#4
    add     r2,#1
    ands    r2,#0xFF
    bne     1b

    mov     r1,#2
    ldr     r0,=INTC
    str     r1,[r0,#SYSCONFIG]      // reset INTC
1:  ldr     r1,[r0,#SYSSTATUS]       // wait for reset completion
    tst     r1,#1
    beq     1b                  // while not zero, continue to check


    pop(r0-r3,r15)


// r0 = interrupt number
// RETURN: r0=0 if it is not a SGI
is_SGI:
    push(r1-r2,r14)
    ldr     r1,=INTC+ISR_SET
    bic     r2,r0,#0b11111
    add     r1,r2
    and     r0,#0b11111
    mov     r2,#1
    lsl     r2,r0
    ldr     r0,[r1]
    and     r0,r2
    pop(r1-r2,r15)

// r0 = interrupt number
generate_SGI:
    push(r0-r2,r14)
    ldr     r1,=INTC+ISR_SET
    bic     r2,r0,#0b11111
    add     r1,r2
    and     r0,#0b11111
    mov     r2,#1
    lsl     r2,r0
    str     r2,[r1]
    pop(r0-r2,r15)

// r0 = interrupt number
clear_SGI:
    push(r0-r2,r14)
    ldr     r1,=INTC+ISR_CLEAR
    bic     r2,r0,#0b11111
    add     r1,r2
    and     r0,#0b11111
    mov     r2,#1
    lsl     r2,r0
    str     r2,[r1]
    pop(r0-r2,r15)



// r2 = int to enable
// r3 = handler address
enableInterrupt:
    push(r0-r2,r14)
    ldr     r0,=handlers
    str     r3,[r0,r2,LSL #2]
    ldr     r0,=INTC+MIR_CLEAR
    // There are 4 registers, 32 bytes apart for interrupt masks. Each reg represent 32 masks.
    // so divide number by 32 and mul back by 32 to get the address of the register
    bic     r1,r2,#0b11111
    add     r0,r1
    mov     r1,#1
    and     r2,#0b11111
    lsl     r1,r2
    str     r1,[r0]

    pop(r0-r2,r15)

handlers:
.skip (256*4)



int_undefined: 
    PRINTK("Undefined interrupt\r\n")
1: b 1b



// The IRQ handler finds the registered handler and transfers control to it
// and guarantees that r0-r12 are untouched. r14 DOES NOT contain a return address.
// the registered handle must jump to returnFromInterrupt
int_IRQ:
    ldr     r13,=IRQ_STACK_TOP          // no re-entrant ints, so reset the stack everytime. This allows us 
    sub     r14,#4                      // must remove #4 from return address according to documentation
    push(r14)                           //    use the current task's IRQ stack
    push(r1)

    // find handler
    ldr     r14,=INTC
    ldr     r1,[r14,#SIR_IRQ]
    and     r1,#0b01111111
    ldr     r14,=handlers
    ldr     r14,[r14,r1,LSL #2]
    pop(r1)                  // we need to guarantee that r0-r12 are clean before going in handler (because of scheduler)
    cmp     r14,#0  
    movne   r15,r14           // jump to handler. That handler will need to call returnFromInterrupt
returnFromInterrupt:                    // from this point, integrity of r0-r12 must be guaranteed!!!
    push(r0-r1)
    // clear software generated interrupt
    ldr     r0,=INTC            
    ldr     r0,[r0,#SIR_IRQ]
    and     r0,#0b01111111
    bl      clear_SGI

    ldr     r0,=INTC
    mov     r1,#1
    str     r1,[r0,#CONTROL]  // EOI
    pop(r0-r1)
    pop(r15)^



// r5 = handler table
// r6 = index
// r7 = handler address
irq_add_soft_handler:
    add     r5,r6,LSL #4 // multiply index by 16, the size of an entry
    str     r7,[r5,#HANDLER_ADDRESS]
    mrc     p15,0,r7,c2,c0,0
    str     r7,[r5,#HANDLER_L1TABLE]
    mrc     p15,0,r7,c13,c0,1
    str     r7,[r5,#HANDLER_ASID]
    mov     r15,r14    

// r5 = handler table
// r6 = index
// r7 = data1
// r8 = data2
irq_invoke_soft_handler:
    push(r0-r3,r12,r14)
    mrc     p15,0,r0,c2,c0,0
    mrc     p15,0,r1,c13,c0,1

    add     r5,r6,LSL #4 // multiply index by 16, the size of an entry
    ldr     r2,[r5,#HANDLER_L1TABLE]
    cmp     r2,#0
    beq     2f
    ldr     r3,[r5,#HANDLER_ASID]
    cmp     r3,r1                   //if same thread, dont switch
    moveq   r12,r13                 // if equal, we will skip the part where we set this.
    beq     2f
    mcr     p15,0,r2,c2,c0,0
    dmb
    mcr     p15,0,r3,c13,c0,1
    isb
    ldr     r2,=KERNEL_PROCESS_LIST_START
    add     r2,r2,r3,LSL #KERNEL_PROCESS_ENTRY_SIZE_SHIFT
    mov     r12,r13
    ldr     r13,[r2,#4]     // get the stack pointer of that thread

2:  ldr     r2,[r5,#HANDLER_ADDRESS]
    blx     r2                          // r7 and r8 will contain data for the handler

    mov     r13,r12                 // restore stack pointer
    // return to crrent context
    mcr     p15,0,r0,c2,c0,0
    dmb
    mcr     p15,0,r1,c13,c0,1
    isb
2:  pop(r0-r3,r12,r15)


