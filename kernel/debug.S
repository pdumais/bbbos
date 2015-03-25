#include "definitions.h"
#include "macros.h"

.global debugprint
.global debugprintRegister
.global debugdumpmem

#define UART UART0


// r4 = pointer to string
debugprint:
    push(r0-r5,r14)
    mov     r0,r4
    mov     r5,#0
1:  ldrb    r1,[r0],#1
    tst     r1,#0xFF
    addne   r5,#1
    bne     1b
    ATOMIC_EXEC(r1)
    ldr     r3,=UART
    bl      uart_send
    ATOMIC_END(r1)
    pop(r0-r5,r15)

// r1 = register to print content
debugprintRegister:
    push(r3-r7,r14)
    ldr     r7,=digits
    ldr     r6,=number
    mov     r4,#8
    ATOMIC_EXEC(r3)
2:  ubfx    r5,r1,#28,#4
    lsl     r1,#4
    ldrb    r5,[r7,r5]
    strb    r5,[r6],#1
    subs    r4,#1
    bne     2b
    mov     r5,#10
    ldr     r4,=number
    ldr     r3,=UART
    bl      uart_send
    ATOMIC_END(r3)
    pop(r3-r7,r15)
digits: .ASCII "0123456789ABCDEF"
number: .skip 8
.ASCII "\r\n"
.align 4


// r0 = pointer to mem
// r1 = bytes count
debugdumpmem:
    push(r2-r10,r14)

//    ATOMIC_EXEC(r10)

4:  ldr     r3,=digits
    mov     r2,#16
    ldr     r7,=line
3:  ldrb    r4,[r0],#1
    ubfx    r5,r4,#4,#4
    and     r4,#0b1111
    ldrb    r5,[r3,r5]
    ldrb    r4,[r3,r4]
    strb    r5,[r7],#1
    strb    r4,[r7],#1
    mov     r5,#' '
    strb    r5,[r7],#1
    subs    r1,#1
    beq     2f
    subs    r2,#1
    bne     3b
    
2:  ldr     r4,=line
    mov     r5,#(16*3)+2
    ldr     r3,=UART
    bl      uart_send
    cmp     r1,#0
    bne     4b
//    ATOMIC_END(r10)
    pop(r2-r10,r15)
    
line: .skip (16*3)
.ASCII "\r\n"
.align 4
