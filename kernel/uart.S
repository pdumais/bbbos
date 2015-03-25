#include "macros.h"
#include "definitions.h"


.global init_uart
.global uart_send

#define SYSC 0x54
#define SYSS 0x58
#define MDR1 0x20
#define EFR  0x08
#define LCR  0x0C
#define DLL  0x00
#define DLH  0x04
#define IER  0x04
#define THR 0
#define SSR 0x44

//WARNING: Only a send_buf function for now. 
//          No interrupts, no receive, no DMA

//TODO interrupt handler for when data is received
//TODO DMA operation to receive data?
//TODO send a buffer (using DMA?)


init_uart:
    push(r0-r3,r14)

    // pin mux
    ldr     r0,=pinmux
    ldr     r3,[r0,#(14*4)] //uart1 rx
    mov     r2,#0b00100000  
    str     r2,[r3]
    ldr     r3,[r0,#(15*4)] //uart1 tx
    mov     r2,#0b00000000   
    str     r2,[r3]
    ldr     r3,[r0,#(2*4)] //uart2 rx
    mov     r2,#0b00100001
    str     r2,[r3]
    ldr     r3,[r0,#(3*4)] //uart2 tx
    mov     r2,#0b00000001
    str     r2,[r3]
    ldr     r3,[r0,#(79*4)] //uart5 rx
    mov     r2,#0b00100100
    str     r2,[r3]
    ldr     r3,[r0,#(78*4)] //uart5 tx
    mov     r2,#0b00000100
    str     r2,[r3]

    bl      prcm_init_uart

    ldr     r0,=UART1
    bl      uart_init
    ldr     r0,=UART2
    bl      uart_init
    ldr     r0,=UART5
    bl      uart_init

    pop(r0-r3,r15)


uart_init:
    push(r1-r3,r14)

    // soft  reset 
    mov     r1,#2
    str     r1,[r0,#SYSC]
1:  ldr     r1,[r0,#SYSS]
    tst     r1,#1
    beq     1b

    mov     r1,#0x7
    str     r1,[r0,#MDR1]
    mov     r1,#0xBF
    str     r1,[r0,#LCR]
    ldr     r1,[r0,#EFR]
    orr     r1,#0b10000
    str     r1,[r0,#EFR]
    mov     r1,#0x00
    str     r1,[r0,#LCR]
    str     r1,[r0,#IER]
    mov     r1,#0xBF
    str     r1,[r0,#LCR]
    mov     r1,#26          //115200 bps
    str     r1,[r0,#DLL]
    mov     r1,#0          //115200 bps
    str     r1,[r0,#DLH]
    mov     r1,#0x00
    str     r1,[r0,#LCR]
    mov     r1,#0x00
    str     r1,[r0,#IER]
    mov     r1,#0xBF
    str     r1,[r0,#LCR]
    ldr     r1,[r0,#EFR]
    bic     r1,#0b10000
    str     r1,[r0,#EFR]
    mov     r1,#3
    str     r1,[r0,#LCR]
    mov     r1,#0x0
    str     r1,[r0,#MDR1]

    PRINTK("test1\r\n")    


    pop(r1-r3,r15)


// r3 = uart
// r4 = buffer
// r5 = size
uart_send:
    push(r1,r4-r5,r14)
1:  ldrb    r1,[r3,#SSR]
    tst     r1,#1
    bne     1b
    ldrb    r1,[r4],#1
    strb    r1,[r3,#THR]
    subs    r5,#1
    bne     1b
    pop(r1,r4-r5,r15)

