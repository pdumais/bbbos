#include "../definitions.h"

.text
    mov     r0,#SWI_SET_GPIO_OUT
    mov     r1,#54
    swi     0

    ldr     r12,=0x100
    mov     r11,#1

testlabel1:
    mov     r2,#242
    mov     r3,#242
    mov     r4,#242
    mov     r5,#242
    mov     r6,#242
    mov     r7,#242
    mov     r8,#242
    mov     r9,#242
    mov     r10,#242
    b testlabel2

.ltorg
.word 0x12345678
.org 5000 // to test program spanning across 2 pages

testlabel2:

    ldr     r1,=str1
    mov     r0,#SWI_PRINTF
    swi     0

    subs    r12,#1
    bne     testlabel1

    ldr     r12,=0x100
    cmp     r11,#1
    moveq   r11,#0
    movne   r11,#1

    mov     r1,#54
    mov     r2,r11    
    mov     r0,#SWI_SET_GPIO_VALUE
    swi     0

    b       testlabel1

str1: .ASCIZ "\rTask 1"
.word 0xDEADBEEF
.word .
