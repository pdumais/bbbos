#include "../definitions.h"

.text
    mov     r0,#SWI_SET_GPIO_IN
    mov     r1,#66                  // p8 header
    ldr     r2,=pinchangedHandler
    swi     0
    mov     r0,#SWI_SET_GPIO_OUT
    mov     r1,#55                  //onboard LED
    swi     0

    mov     r0,#SWI_MCP23S18_REGISTER
    ldr     r1,=pinchangedHandler2
    swi     0

    mov     r0,#SWI_MCP23S18_CONFIGURE_PIN
    mov     r1,#0
    mov     r2,#MCP23S18_PIN_OUTPUT
    swi     0
    mov     r0,#SWI_MCP23S18_CONFIGURE_PIN
    mov     r1,#8
    mov     r2,#MCP23S18_PIN_OUTPUT
    swi     0
    mov     r0,#SWI_MCP23S18_CONFIGURE_PIN
    mov     r1,#1
    mov     r2,#MCP23S18_PIN_INPUT|MCP23S18_PIN_INTENA|MCP23S18_PIN_PULLUP
    swi     0
    mov     r0,#SWI_MCP23S18_CONFIGURE_PIN
    mov     r1,#9
    mov     r2,#MCP23S18_PIN_INPUT|MCP23S18_PIN_INTENA|MCP23S18_PIN_PULLUP
    swi     0
    mov     r0,#SWI_MCP23S18_ACTIVATE_PIN
    mov     r1,#8
    mov     r2,#MCP23S18_PIN_ACTIVATE
    swi     0


    mov     r2,#2
    mov     r3,#3
    mov     r4,#4
    mov     r5,#5
    mov     r6,#6
    mov     r7,#7
    mov     r8,#8
    mov     r9,#9
    mov     r10,#10
    mov     r11,#11
    mov     r12,#12

    sub     r13,#4096
    push(r0)
    pop(r0)
    add     r13,#4096
1:
    ldr     r1,=str1
    mov     r0,#SWI_PRINTF
    swi     0

    cmp     r2,#2
    bne     contextSwitchBroken
    cmp     r3,#3
    bne     contextSwitchBroken
    cmp     r4,#4
    bne     contextSwitchBroken
    cmp     r5,#5
    bne     contextSwitchBroken
    cmp     r6,#6
    bne     contextSwitchBroken
    cmp     r7,#7
    bne     contextSwitchBroken
    cmp     r8,#8
    bne     contextSwitchBroken
    cmp     r9,#9
    bne     contextSwitchBroken
    cmp     r10,#10
    bne     contextSwitchBroken
    cmp     r11,#11
    bne     contextSwitchBroken
    cmp     r12,#12
    bne     contextSwitchBroken

    push(r1-r2)
    ldr     r1,=ledmcp9
    ldr     r1,[r1]
    tst     r1,#1
    movne   r2,#MCP23S18_PIN_ACTIVATE
    moveq   r2,#MCP23S18_PIN_DEACTIVATE
    mov     r0,#SWI_MCP23S18_ACTIVATE_PIN
    mov     r1,#0
    swi     0


    ldr     r1,=led55
    ldr     r1,[r1]
    cmp     r1,#1
    bne     2f
    mov     r1,#55
    mov     r2,#0
    mov     r0,#SWI_SET_GPIO_VALUE
    swi     0
2:  cmp     r1,#2
    bne     2f
    mov     r1,#55
    mov     r2,#1
    mov     r0,#SWI_SET_GPIO_VALUE
    swi     0
2:  ldr     r1,=led55
    mov     r0,#0
    str     r0,[r1]


    pop(r1-r2)

    b 1b



pinchangedHandler2:
    push(r0-r1,r14)
    ldr     r1,=str4
    mov     r0,#SWI_PRINTF
    swi     0

    mov     r0,#SWI_MCP23S18_GET_ACTIVE_PINS
    swi     0
    ldr     r0,=(1<<1)
    tst     r1,r0
    movne   r1,#0
    moveq   r1,#1
    ldr     r0,=ledmcp9
    str     r1,[r0]
    pop(r0-r1,r15)

pinchangedHandler:
    push(r0-r1,r14)

    ldr     r0,=led55
    cmp     r8,#0
    moveq   r1,#2
    movne   r1,#1
    str     r1,[r0]

    ldr     r1,=str3
    mov     r0,#SWI_PRINTF
    swi     0
    pop(r0-r1,r15)


contextSwitchBroken:
    ldr     r1,=str2
    mov     r0,#SWI_PRINTF
    swi     0
    1:b 1b


str1: .ASCIZ "\rTask 2"
str2: .ASCIZ "Context Switch Broken\r\n"
str3: .ASCIZ "Pin changed\r\n"
str4: .ASCIZ "MCP23s18 changed\r\n"
.word 0x111BAB00
.align(4)
led55: .word 0
ledmcp9: .word 0
