#include "macros.h"
#include "definitions.h"
#include "interupts.h"

.global init_gpio
.global gpio_configure_output_pin
.global gpio_configure_input_pin
.global gpio_set_pin_status
.global gpio_get_pin_status
.global pinmux

#define GPIO_SYSCONFIG        0x010 
#define GPIO_EOI              0x020
#define GPIO_IRQSTATUS_RAW_0  0x024
#define GPIO_IRQSTATUS_RAW_1  0x028
#define GPIO_IRQSTATUS_0      0x02C
#define GPIO_IRQSTATUS_1      0x030
#define GPIO_IRQSTATUS_SET_0  0x034
#define GPIO_IRQSTATUS_SET_1  0x038
#define GPIO_IRQSTATUS_CLR_0  0x03C
#define GPIO_IRQSTATUS_CLR_1  0x040
#define GPIO_IRQWAKEN_0       0x044
#define GPIO_IRQWAKEN_1       0x048
#define GPIO_SYSSTATUS        0x114
#define GPIO_CTRL             0x130
#define GPIO_OE               0x134
#define GPIO_DATAIN           0x138
#define GPIO_DATAOUT          0x13C
#define GPIO_LEVELDETECT0     0x140
#define GPIO_LEVELDETECT1     0x144
#define GPIO_RISINGDETECT     0x148
#define GPIO_FALLINGDETECT    0x14C
#define GPIO_DEBOUNCENABLE    0x150
#define GPIO_DEBOUNCINGTIME   0x154
#define GPIO_CLEARDATAOUT     0x190
#define GPIO_SETDATAOUT       0x194  


init_gpio:
    push(r0-r3,r14)

    bl      prcm_init_gpio

    ldr     r0,=GPIO0
    bl      gpioinit
    ldr     r0,=GPIO1
    bl      gpioinit
    ldr     r0,=GPIO2
    bl      gpioinit
    ldr     r0,=GPIO3
    bl      gpioinit

    mov     r2,#GPIO0_INTERRUPT
    ldr     r3,=gpioHandler0
    bl      enableInterrupt
    mov     r2,#GPIO1_INTERRUPT
    ldr     r3,=gpioHandler1
    bl      enableInterrupt
    mov     r2,#GPIO2_INTERRUPT
    ldr     r3,=gpioHandler2
    bl      enableInterrupt
    mov     r2,#GPIO3_INTERRUPT
    ldr     r3,=gpioHandler3
    bl      enableInterrupt

    pop(r0-r3,r15)


gpioinit:
    mov     r1,#0
    str     r1,[r0,#GPIO_CTRL]
    
    mov     r1,#2
    str     r1,[r0,#GPIO_SYSCONFIG]
1:  ldr     r1,[r0,#GPIO_SYSSTATUS]
    tst     r1,#1
    beq     1b  
    mov     r1,#255
    str     r1,[r0,#GPIO_DEBOUNCINGTIME]
    mvn     r2,#0
    str     r2,[r0,#GPIO_IRQSTATUS_CLR_0]
    str     r2,[r0,#GPIO_IRQSTATUS_CLR_1]
    mov     r15,r14


// r0 = pin number
// RETURN: r0= register, r1 = index
//WARNING: r2 will nbe dirty
pin_to_register:
    and     r2,r0,#0b11111
    mov     r1,#1
    lsl     r1,r2
    lsr     r0,#5
    lsl     r0,#2
    ldr     r2,=registers
    ldr     r0,[r2,r0]
    mov     r15,r14
registers: .word GPIO0,GPIO1,GPIO2,GPIO3


// r0= pin number (0..127)
gpio_configure_output_pin:
    push(r0-r3,r14)

    // change mode 
    ldr     r3,=pinmux
    ldr     r3,[r3,r0,LSL #2]
    mov     r2,#0b0011111       //not receiver, pullup, mode 7
    str     r2,[r3]

    bl      pin_to_register

    // set as output
    ldr     r2,[r0,#GPIO_OE]
    bic     r2,r1
    str     r2,[r0,#GPIO_OE]

    // disable interrupt
    str     r1,[r0,#GPIO_IRQSTATUS_CLR_0]

    pop(r0-r3,r15)

// Input pins have a pullup resistor enabled. GPIO must connected to ground to be low, floating to be high
// r0= pin number (0..127)
// r3= pointer to status changed handler (null if no handler is needed)
// r4 = 1=rise detect, 2=falling detect, 3 = both, 4=level1 detect
gpio_configure_input_pin:
    push(r0-r7,r14)

    mov     r6,r0

    // change mode 
    push(r4)
    ldr     r4,=pinmux
    ldr     r4,[r4,r0,LSL #2]
    mov     r2,#0b0110111   // receiver, pullup, mode 7
    str     r2,[r4]
    pop(r4)
    bl      pin_to_register


    //set data in
    ldr     r2,[r0,#GPIO_OE]
    orr     r2,r1
    str     r2,[r0,#GPIO_OE]

    //register handler
    ldr     r5,=handlersTable
    mov     r7,r3
    bl      irq_add_soft_handler

    //enable interrupt
    str     r1,[r0,#GPIO_IRQSTATUS_SET_0]
    ldr     r2,[r0,#GPIO_LEVELDETECT0]
    tst     r4,#4
    biceq   r2,r1
    orrne   r2,r1
    str     r2,[r0,#GPIO_LEVELDETECT0]
    ldr     r2,[r0,#GPIO_LEVELDETECT1]
    bic     r2,r1
    str     r2,[r0,#GPIO_LEVELDETECT1]
    
    tst     r4,#1 
    ldr     r2,[r0,#GPIO_RISINGDETECT]
    orrne   r2,r1
    biceq   r2,r1
    str     r2,[r0,#GPIO_RISINGDETECT]
    tst     r4,#2
    ldr     r2,[r0,#GPIO_FALLINGDETECT]
    orrne   r2,r1
    biceq   r2,r1
    str     r2,[r0,#GPIO_FALLINGDETECT]
    
    //config debounce
    ldr     r2,[r0,#GPIO_DEBOUNCENABLE]
    orr     r2,r1
    str     r2,[r0,#GPIO_DEBOUNCENABLE]
       

    pop(r0-r7,r15)



gpioHandler0:
    push(r0-r3)
    ldr     r0,=GPIO0
    mov     r2,#0
    b       allHandlers
gpioHandler1:
    push(r0-r3)
    ldr     r0,=GPIO1
    mov     r2,#32
    b       allHandlers
gpioHandler2:
    push(r0-r3)
    ldr     r0,=GPIO2
    mov     r2,#64
    b       allHandlers
gpioHandler3:
    push(r0-r3)
    ldr     r0,=GPIO3
    mov     r2,#96
allHandlers:
    ldr     r1,[r0,#GPIO_IRQSTATUS_0] // get active IRQ
    rbit    r3,r1
    clz     r3,r3   // if ther are two interrupts pending, this will only take one. So the handler will be triggered again
    add     r2,r3

    push(r5-r8)
    mov     r7,r2
    ldr     r8,[r0,#GPIO_DATAIN]
    and     r8,r1
    mov     r6,r2
    ldr     r5,=handlersTable
    bl      irq_invoke_soft_handler
    pop(r5-r8)

    mov     r2,#1
    lsl     r2,r3
    str     r2,[r0,#GPIO_IRQSTATUS_0] // release IRQ line
    mov     r1,#1
    str     r1,[r0,#GPIO_EOI] // release IRQ line
    pop(r0-r3)
    b       returnFromInterrupt



// r0 = pin number
// r3 = state
gpio_set_pin_status:
    push(r0-r3,r14)
    bl      pin_to_register


    cmp     r3,#0
    addeq   r0,#GPIO_CLEARDATAOUT
    addne   r0,#GPIO_SETDATAOUT
    str     r1,[r0]

    pop(r0-r3,r15)


// r0 = pin number
// RETURN: r3 = state
gpio_get_pin_status:
    push(r0-r3,r14)

    bl      pin_to_register
    //TODO: get pin status and return it
    pop(r0-r3,r15)


handlersTable: HANDLERTABLE(128)
pinmux: .WORD 0x44e10948,\
0x44e1094c,\
0x44e10950,\
0x44e10954,\
0x44e10958,\
0x44e1095c,\
0x44e10960,\
0x44e10964,\
0x44e108d0,\
0x44e108d4,\
0x44e108d8,\
0x44e108dc,\
0x44e10978,\
0x44e1097c,\
0x44e10980,\
0x44e10984,\
0x44e1091c,\
0x44e10920,\
0x44e10a1c,\
0x44e109b0,\
0x44e109b4,\
0x44e10924,\
0x44e10820,\
0x44e10824,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0x44e10828,\
0x44e1082c,\
0x44e10928,\
0x44e10944,\
0x44e10870,\
0x44e10874,\
0x44e10800,\
0x44e10804,\
0x44e10808,\
0x44e1080c,\
0x44e10810,\
0x44e10814,\
0x44e10818,\
0x44e1081c,\
0x44e10968,\
0x44e1096c,\
0x44e10970,\
0x44e10974,\
0x44e10830,\
0x44e10834,\
0x44e10838,\
0x44e1083c,\
0x44e10840,\
0x44e10844,\
0x44e10848,\
0x44e1084c,\
0x44e10850,\
0x44e10854,\
0x44e10858,\
0x44e1085c,\
0x44e10860,\
0x44e10864,\
0x44e10868,\
0x44e1086c,\
0x44e10878,\
0x44e1087c,\
0x44e10880,\
0x44e10884,\
0x44e10888,\
0x44e1088c,\
0x44e10890,\
0x44e10894,\
0x44e10898,\
0x44e1089c,\
0x44e108a0,\
0x44e108a4,\
0x44e108a8,\
0x44e108ac,\
0x44e108b0,\
0x44e108b4,\
0x44e108b8,\
0x44e108bc,\
0x44e108c0,\
0x44e108c4,\
0x44e108c8,\
0x44e108cc,\
0x44e10934,\
0x44e10938,\
0x44e1093c,\
0x44e10940,\
0x44e108e0,\
0x44e108e4,\
0x44e108e8,\
0x44e108ec,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0xFFFFFFFF,\
0x44e10990,\
0x44e10994,\
0x44e10998,\
0x44e1099c,\
0x44e109a0,\
0x44e109a4,\
0x44e109a8,\
0x44e109ac,\
