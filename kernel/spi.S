#include "macros.h"
#include "definitions.h"

.global init_spi
.global spi_send_byte
.global spi_send_string
.global spi_read_string
.global spi_enable_cs
.global spi_disable_cs
.global spi_activate_channel


#define SPI_SYSCONFIG 0x110
#define SPI_SYSSTATUS 0x114
#define SPI_IRQSTATUS 0x118
#define SPI_IRQENABLE 0x11C
#define SPI_SYST      0x124
#define SPI_MODULCTRL 0x128
#define SPI_CH0CONF   0x12C
#define SPI_CH0STAT   0x130
#define SPI_CH0CTRL   0x134
#define SPI_TX0       0x138
#define SPI_RX0       0x13C
#define SPI_CH1CONF   0x140
#define SPI_CH1STAT   0x144
#define SPI_CH1CTRL   0x148
#define SPI_TX1       0x14C
#define SPI_RX1       0x150

///////////////// WARNING: THIS CODE DOES NOT WORK< AND IS NOT USED
init_spi:
    push(r0-r3,r14)

    bl      prcm_init_spi

    PRINTK("  Using pins 110,111,112. 113 and 7 for cs0 and cs1\r\n")
    ldr     r0,=pinmux
    ldr     r3,[r0,#(110*4)]    // sck
    mov     r2,#0b00110011       // mode 3, no pullup
    str     r2,[r3]
    ldr     r3,[r0,#(111*4)]    // d0 (MOSI)
    mov     r2,#0b00010011       // mode 3, no pullup
    str     r2,[r3]
    ldr     r3,[r0,#(112*4)]    // d1 (MISO)
    mov     r2,#0b00110011       //mode 3, no pullup, receive enabled
    str     r2,[r3]
    ldr     r3,[r0,#(113*4)]    // cs0
    mov     r2,#0b00011011       // pullup, mode 3
    str     r2,[r3]
    ldr     r3,[r0,#(7*4)]       // cs1
    mov     r2,#0b00011010       // pullup, mode 2
    str     r2,[r3]
    ldr     r3,[r0,#(114*4)]     // GPIO3.18 must be set as input since it is connected with gpio7 on BBB
    mov     r2,#0b00100010       // mode 2
    str     r2,[r3]


    ldr     r0,=SPI1
    mov     r1,#2
    str     r1,[r0,#SPI_SYSCONFIG]
1:  ldr     r1,[r0,#SPI_SYSSTATUS]
    tst     r1,#1
    beq     1b

    // use single mode. This will allow us to activate only one channel at a time.
    // We will need to drive the CS pin manually using CHxCONF[20]
    mov     r1,#1
    str     r1,[r0,#SPI_MODULCTRL]

    ldr     r1,=(1<<18)|(1<<17)|(7<<7)|(1<<6)|(2<<2) // mode 0
    str     r1,[r0,#SPI_CH0CONF]
    ldr     r1,=(1<<18)|(1<<17)|(7<<7)|(1<<6)|(3<<2) // mode 0
    str     r1,[r0,#SPI_CH1CONF]
    mov     r1,#0             
    str     r1,[r0,#SPI_CH0CTRL]// disable channel 0
    str     r1,[r0,#SPI_CH1CTRL]// disable channel 1

    pop(r0-r3,r15)


//r4 = channel
//r5 0=deactivate, 1= activate
spi_activate_channel:
    push(r0-r1,r14)
    ldr     r0,=SPI1
    mov     r1,#0x14
    mla     r0,r4,r1,r0
    str     r5,[r0,#SPI_CH0CTRL]
    pop(r0-r1,r15)

//r4 = channel
//r5 = byte to send
//RETURN r5 = byte received
spi_send_byte:
    push(r0-r1,r14)
    ldr     r0,=SPI1
    mov     r1,#0x14
    mla     r0,r4,r1,r0

1:  ldr     r1,[r0,#SPI_CH0STAT]
    tst     r1,#2
    beq     1b
    str     r5,[r0,#SPI_TX0]
1:  ldr     r1,[r0,#SPI_CH0STAT]
    tst     r1,#1
    beq     1b
    ldr     r5,[r0,#SPI_RX0]

    pop(r0-r1,r15)

//r4 = channel
//r5 = buffer
//r6 = number of bytes to send
spi_send_string:
    push(r0-r6,r14)
    ldr     r0,=SPI1
    mov     r1,#0x14
    mla     r0,r4,r1,r0

    mov     r1,#1
2:  ldr     r1,[r0,#SPI_CH0STAT]
    tst     r1,#2
    beq     2b
    ldrb    r2,[r5],#1
    str     r2,[r0,#SPI_TX0]
1:  ldr     r1,[r0,#SPI_CH0STAT]
    tst     r1,#1
    beq     1b
    ldr     r2,[r0,#SPI_RX0]
    subs    r6,#1
    bne     2b

    pop(r0-r6,r15)


//r4 = channel
//r5 = buffer
//r6 = number of bytes to read
spi_read_string:
    push(r0-r6,r14)
    ldr     r0,=SPI1
    mov     r1,#0x14
    mla     r0,r4,r1,r0

2:  ldr     r1,[r0,#SPI_CH0STAT]
    tst     r1,#2
    beq     2b
    str     r2,[r0,#SPI_TX0]    // put anything in buffer
1:  ldr     r1,[r0,#SPI_CH0STAT]
    tst     r1,#1
    beq     1b
    ldr     r2,[r0,#SPI_RX0]
    strb    r2,[r5],#1
    subs    r6,#1
    bne     2b

    pop(r0-r6,r15)


//r4 = channel
spi_enable_cs:
    push(r0-r2,r14)
    ldr     r0,=SPI1
    mov     r1,#0x14
    mla     r0,r4,r1,r0

    ldr     r2,=(1<<20)
    ldr     r1,[r0,#SPI_CH0CONF]
    orr     r1,r2
    str     r1,[r0,#SPI_CH0CONF] //enable CS

    pop(r0-r2,r15)

//r4 = channel
spi_disable_cs:
    push(r0-r2,r14)
    ldr     r0,=SPI1
    mov     r1,#0x14
    mla     r0,r4,r1,r0

    ldr     r2,=(1<<20)
    ldr     r1,[r0,#SPI_CH0CONF]
    bic     r1,r2
    str     r1,[r0,#SPI_CH0CONF] //disable CS

    pop(r0-r2,r15)








