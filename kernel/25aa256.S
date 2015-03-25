#include "macros.h"
#include "definitions.h"

.global init_25aa256
.global read_25aa256
.global write_25aa256


init_25aa256:
    push(r0-r5,r14)
    PRINTK("  Using SPI1 Channel 1\r\n")

    pop(r0-r5,r15)


//RETURN: r5 = status
read_status_register_25aa256:
    push(r0-r4,r14)
    // read status register
    mov     r4,#EEPROMCS
    mov     r5,#1
    bl      spi_activate_channel

    bl      spi_enable_cs
    mov     r5,#0b101
    bl      spi_send_byte
    mov     r5,#0
    bl      spi_send_byte
    bl      spi_disable_cs

    mov     r5,#0
    bl      spi_activate_channel
    pop(r0-r4,r15)


//r1 = address (WARNING: must be on a 64bytes boundary)
//r2 = size to read
//r3 = buffer
read_25aa256:
    push(r0-r5,r14)
    ATOMIC_EXEC(r0)
    mov     r4,#EEPROMCS
    mov     r5,#1
    bl      spi_activate_channel

1:  bl      spi_enable_cs
    mov     r5,#0b011       // READ command
    bl      spi_send_byte
    // write address
    ubfx    r5,r1,#8,#8
    bl      spi_send_byte
    and     r5,r1,#0xFF
    bl      spi_send_byte

    mov     r5,r3
    cmp     r2,#64
    movhs   r6,#64
    movlo   r6,r2
    bl      spi_read_string
    bl      spi_disable_cs
    add     r3,r6
    add     r1,r6
    subs    r2,r6
    bne     1b

    mov     r5,#0
    bl      spi_activate_channel
    ATOMIC_END(r0)
    pop(r0-r5,r15)


//r1 = address  (WARNING: must be on a 64bytes boundary)
//r2 = size to read
//r3 = buffer
write_25aa256:
    push(r0-r5,r14)
    ATOMIC_EXEC(r0)
    mov     r4,#EEPROMCS
    mov     r5,#1
    bl      spi_activate_channel

    // enable write latch (leave it enabled always
1:  bl      spi_enable_cs
    mov     r5,#0b110
    bl      spi_send_byte
    bl      spi_disable_cs
    bl      spi_enable_cs

    mov     r5,#0b010       // WRITE command
    bl      spi_send_byte

    // write address
    ubfx    r5,r1,#8,#8
    bl      spi_send_byte
    and     r5,r1,#0xFF
    bl      spi_send_byte

    //write the whole thing, 64bytes at a time
    mov     r5,r3
    cmp     r2,#64
    movhs   r6,#64
    movlo   r6,r2
    bl      spi_send_string
    bl      spi_disable_cs

    // wait for write completion
2:  bl      read_status_register_25aa256
    tst     r5,#1   // test if Write In Progess is set
    bne     2b

    add     r3,r6
    add     r1,r6
    subs    r2,r6
    bne     1b

    mov     r5,#0
    bl      spi_activate_channel

    ATOMIC_END(r0)
    pop(r0-r5,r15)

