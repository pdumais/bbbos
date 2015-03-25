#include "definitions.h"
#include "macros.h"
#include "interupts.h"

.extern initMMU
.extern loadProgram
.extern schedule
.extern initProcessManager
.extern initSchedulerTimer
.extern initINTC
.extern generate_SGI
.extern init_emmc
.extern init_gpio

.text
entryPoint:
    // load int vector into VBAR
    ldr     r0,=IDT_START
    mcr     p15,0,r0,c12,c0,0

    // initialize stack for all modes, except user mode because we will set it on process creation
    msr     CPSR_c,#0b11010001           // stack for FIQ mode
    ldr     r13,=STACK_BASE_FIQ
    msr     CPSR_c,#0b11010111           // stack for Abort mode
    ldr     r13,=STACK_BASE_ABORT  
    msr     CPSR_c,#0b11011011           // stack for Undefined mode
    ldr     r13,=STACK_BASE_UNDEFINED 
    msr     CPSR_c,#0b11010011           // stack for Supervisor mode. And we will stay in that mode
    ldr     r13,=STACK_BASE_UNDEFINED   // This is temporary, We will use another stack after MMU is init

    // Disable TEX remap
    mrc     p15,0,r0,c1,c0,0
    bic     r0,#28
    mcr     p15,0,r0,c1,c0,0

    bl      init_uart


    PRINTK("Booting\r\n")
    PRINTK("Init MMU\r\n")
    bl      initMMU

    ldr     r13,=SVC_STACK_TOP          // now that mmu is setup, use proper stack

    PRINTK("Init Interrupt Controller\r\n")
    bl      initINTC

    PRINTK("Init emmc\r\n")
    bl      init_emmc

    PRINTK("Init Process Manager\r\n")
    bl      initProcessManager

    PRINTK("Init Scheduler\r\n")
    ldr     r1,=TIMER0_RELOAD_VALUE
    bl      initSchedulerTimer

    PRINTK("Init GPIO\r\n")
    bl      init_gpio

    PRINTK("Init SPI\r\n")
    bl      init_spi

    PRINTK("Init EEPROM\r\n")
    bl      init_25aa256

    PRINTK("Init Port Expander\r\n")
    bl      init_mcp23s18


ldr r1,=0x1000
mov r2,#128
ldr r3,=test
bl read_25aa256
PRINTREG(r3)
PRINTMEM2(r3,128)
PRINTK("\r\n")

    PRINTK("Loading programs\r\n")
    mov     r4,#1
    bl      loadProgram
    mov     r11,r0

    mov     r4,#2
    bl      loadProgram
    mov     r10,r0

    PRINTK("System is up. Entering spin-wait\r\n")
    // Enable interrupts
    mrs     r0,CPSR
    bic     r0,#0b11000000
    msr     CPSR,r0

kernelIdleLoop: 
    wfi
    b       kernelIdleLoop

.align 5 // interupt vector needs to be aligned on a 32bytes boundary
IDT_START:
IDT_RESET
IDT_UNDEFINED_INSTRUCTION
IDT_SWI
IDT_INSTRUCTION_FETCH_ABORT
IDT_DATA_ABORT
IDT_RESERVED
IDT_IRQ
IDT_FIRQ
.ltorg // this will dump the literal pool here. Needed for IDT
IDT_END:
test:
.skip 256
