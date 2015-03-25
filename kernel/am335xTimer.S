// This is a driver for the SP804 Dual timer that is present on the realview-pb-a8 board.
// ARM Dual-Timer Module (SP804) Technical Reference Manual

#include "macros.h"
#include "definitions.h"

.global initSchedulerTimer
.extern enableInterrupt
.extern schedule2
.extern returnFromInterrupt
.extern prcm_init_timer

#define TIOCP_CFG        0x10
#define IRQ_EOI          0x20
#define IRQSTATUS_RAW    0x24
#define IRQSTATUS        0x28
#define IRQENABLE_SET    0x2C
#define IRQENABLE_CLR    0x30
#define IRQWAKEEN        0x34
#define TCLR             0x38
#define TCRR             0x3C
#define TLDR             0x40
#define TTGR             0x44
#define TWPS             0x48
#define TMAR             0x4C
#define TCAR1            0x50
#define TSICR            0x54
#define TCAR2            0x58

// r1 = period
initSchedulerTimer:
    push(r0-r3,r14)

    mov     r2,#SCHEDULER_TIMER_INTERRUPT
    ldr     r3,=timerHandler
    bl      enableInterrupt


    mov     r0,#SCHEDULER_TIMER_ID
    bl      prcm_init_timer

    ldr     r0,=SCHEDULER_TIMER_BASE
    mov     r2,#1
    str     r2,[r0,#TIOCP_CFG]       // Reset
1:  ldr     r2,[r0,#TIOCP_CFG]
    tst     r2,#1
    bne     1b

    mov     r2,#2
    str     r2,[r0,#IRQENABLE_SET]  // enable interrupt for overflow
    str     r1,[r0,#TLDR]  
    str     r1,[r0,#TCRR]  
    mov     r2,#0b100011|(SCHEDULER_TIMER_PRESCALE<<2)
    str     r2,[r0,#TCLR]  // start, auto-reload

    pop(r0-r3,r15)


timerHandler:
    push(r0-r1)
    mov     r0,#SCHEDULER_TIMER_INTERRUPT
    bl      is_SGI
    cmp     r0,#0
    bne     1f                          // no need to ACK the timer if this was an SGI
    ldr     r0,=SCHEDULER_TIMER_BASE
    mov     r1,#2
    str     r1,[r0,#IRQSTATUS]   // Ack timer int
    mov     r1,#0
    str     r1,[r0,#IRQ_EOI]   // Ack timer int
1:  pop(r0-r1)
    bl      schedule2                   // that function will call reutnrFromInterrupt

