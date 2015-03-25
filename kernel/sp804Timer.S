// This is a driver for the SP804 Dual timer that is present on the realview-pb-a8 board.
// ARM Dual-Timer Module (SP804) Technical Reference Manual

#include "macros.h"
#include "definitions.h"

.global initSchedulerTimer
.extern enableInterrupt
.extern schedule2

#define TIMER_ENABLE 0b10000000
#define TIMER_PERIODIC 0b01000000
#define TIMER_PGENINT 0b00100000
#define TIMER_PRESCALE1 0b0000
#define TIMER_PRESCALE16 0b0100
#define TIMER_PRESCALE256 0b1000
#define TIMER_32BIT 0b10

#if TIMER0_PRESCALE==256
#define PRESCALE TIMER_PRESCALE256
#elif TIMER0_PRESCALE==16
#define PRESCALE TIMER_PRESCALE16
#else
#define PRESCALE TIMER_PRESCALE1
#endif


// r1 = period
initSchedulerTimer:
    push(r0-r3,r14)

    mov     r2,#TIMER01_INTERRUPT
    ldr     r3,=timerHandler
    bl      enableInterrupt

    ldr     r0,=TIMER01_BASE
    str     r1,[r0,#TIMER1LOAD]    

    mov     r1,#TIMER_ENABLE|TIMER_PERIODIC|TIMER_PGENINT|PRESCALE|TIMER_32BIT
    str     r1,[r0,#TIMER1CONTROL]
    
    mvn     r1,#0
    str     r1,[r0,#TIMER_PGENINT]

    pop(r0-r3,r15)


timerHandler:
    push(r0-r1)
    ldr     r0,=TIMER01_BASE
    mov     r1,#1
    str     r1,[r0,#TIMER1INTCLR]       // Ack timer int
    pop(r0-r1)
    bl      schedule2                   // that function will call reutnrFromInterrupt

