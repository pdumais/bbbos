#include "definitions.h"
#include "macros.h"

.global prcm_init_timer
.global prcm_init_gpio
.global prcm_init_spi
.global prcm_init_uart

timer_clk: .WORD CLKSEL_TIMER2_CLK,CLKSEL_TIMER3_CLK,CLKSEL_TIMER4_CLK,CLKSEL_TIMER5_CLK,CLKSEL_TIMER6_CLK,CLKSEL_TIMER7_CLK
timer_control: .WORD TIMER2_CONTROL,TIMER3_CONTROL,TIMER4_CONTROL,TIMER5_CONTROL,TIMER6_CONTROL,TIMER7_CONTROL
timer_gclk: .WORD CLKACTIVITY_TIMER2,CLKACTIVITY_TIMER3,CLKACTIVITY_TIMER4,CLKACTIVITY_TIMER5,CLKACTIVITY_TIMER6,CLKACTIVITY_TIMER7

// ro = index of timer
prcm_init_timer:
    push(r0-r3,r14)


    sub     r0,#2

    // Timer clock source selection
    ldr     r3,=timer_clk 
    add     r3,r0,LSL #2
    ldr     r3,[r3]
    ldr     r2,=CLOCK_MODULE_PLL
    add     r3,r2
    mov     r2,#2
    str     r2,[r3]         // select the 32khz clock
1:  ldr     r2,[r3]
    tst     r2,#0b10
    beq     1b

    // Enable module
    ldr     r3,=timer_control 
    add     r3,r0,LSL #2
    ldr     r3,[r3]
    ldr     r2,=CLOCK_MODULE_PERIPHERAL
    add     r3,r2
    mov     r2,#2 // enable
    str     r2,[r3]
1:  ldr     r2,[r3]
    tst     r2,#0b10
    beq     1b

    ldr     r1,=timer_gclk
    add     r1,r0,LSL #2
    ldr     r1,[r1]
    ldr     r3,=CLOCK_MODULE_PERIPHERAL
1:  ldr     r2,[r3,#CM_PER_L4LS_CLKSTCTRL]
    ands    r1,r2
    beq     1b

    //TODO: not sure why I need a delay like this. I checked all the flags previously.
    // If I dont put a delay, memory access to the device will cause a data abort.
    // as if the data was not ready yet or something.
    ldr r1,=0x100000
    1: subs r1,#1
    bne 1b

    pop(r0-r3,r15)


prcm_init_gpio:
    push(r0-r2,r14)

    ldr     r0,=CLOCK_MODULE_WAKEUP
    ldr     r1,=(1<<18)|2
    str     r1,[r0,#CM_WKP_GPIO0_CLKCTRL]
1:  ldr     r2,[r0,#CM_WKP_GPIO0_CLKCTRL]
    cmp     r1,r2
    bne     1b

    ldr     r0,=CLOCK_MODULE_PERIPHERAL
    str     r1,[r0,#CM_PER_GPIO1_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_GPIO1_CLKCTRL]
    cmp     r1,r2
    bne     1b
    str     r1,[r0,#CM_PER_GPIO2_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_GPIO2_CLKCTRL]
    cmp     r1,r2
    bne     1b
    str     r1,[r0,#CM_PER_GPIO3_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_GPIO3_CLKCTRL]
    cmp     r1,r2
    bne     1b

    // Wiat for GPIO 0 clock to be active
    ldr     r1,=(1<<8)
    ldr     r0,=CLOCK_MODULE_WAKEUP
1:  ldr     r2,[r0,#CM_WKUP_CLKSTCTRL]
    and     r2,r1
    cmp     r2,r1
    bne     1b    

    // Wiat for GPIO1,2,3 clock to be active
    ldr     r1,=(1<<21)|(1<<20)|(1<<19)
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
1:  ldr     r2,[r0,#CM_PER_L4LS_CLKSTCTRL]
    and     r2,r1
    cmp     r2,r1
    bne     1b    

    pop(r0-r2,r15)


prcm_init_spi:
    push(r0-r2,r14)

    mov     r1,#2
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
    str     r1,[r0,#CM_PER_SPI1_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_SPI1_CLKCTRL]
    cmp     r1,r2
    bne     1b

    // Wiat for GPIO1,2,3 clock to be active
    ldr     r1,=(1<<25)|(1<<8)
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
1:  ldr     r2,[r0,#CM_PER_L4LS_CLKSTCTRL]
    and     r2,r1
    cmp     r2,r1
    bne     1b

    pop(r0-r2,r15)

prcm_init_uart:
    push(r0-r2,r14)

    mov     r1,#2
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
    str     r1,[r0,#CM_PER_UART1_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_UART1_CLKCTRL]
    cmp     r1,r2
    bne     1b
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
    str     r1,[r0,#CM_PER_UART2_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_UART2_CLKCTRL]
    cmp     r1,r2
    bne     1b
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
    str     r1,[r0,#CM_PER_UART3_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_UART3_CLKCTRL]
    cmp     r1,r2
    bne     1b
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
    str     r1,[r0,#CM_PER_UART4_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_UART4_CLKCTRL]
    cmp     r1,r2
    bne     1b
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
    str     r1,[r0,#CM_PER_UART5_CLKCTRL]
1:  ldr     r2,[r0,#CM_PER_UART5_CLKCTRL]
    cmp     r1,r2
    bne     1b

    ldr     r1,=(1<<10)
    ldr     r0,=CLOCK_MODULE_PERIPHERAL
1:  ldr     r2,[r0,#CM_PER_L4LS_CLKSTCTRL]
    and     r2,r1
    cmp     r2,r1
    bne     1b

    pop(r0-r2,r15)

