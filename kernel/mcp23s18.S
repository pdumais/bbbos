#include "macros.h"
#include "definitions.h"
#include "mcp23s18.h"

.global init_mcp23s18
.global mcp23s18_register_handler
.global mcp23s18_get_active_pins
.global mcp23s18_activate_pin
.global mcp23s18_configure_pin

#define READOPCODE 0b01000001
#define WRITEOPCODE 0b01000000

#define IODIRA 0x00
#define IODIRB 0x01
#define IPOLA 0x02
#define IPOLB 0x03
#define GPINTENA 0x04
#define GPINTENB 0x05
#define DEFVALA 0x06
#define DEFVALB 0x07
#define INTCONA 0x08
#define INTCONB 0x09
#define IOCON 0x0A
#define GPPUA 0x0C
#define GPPUB 0x0D
#define INTFA 0x0E
#define INTFB 0x0F
#define INTCAPA 0x10
#define INTCAPB 0x11
#define GPIOA 0x12
#define GPIOB 0x13
#define OLATA 0x14
#define OLATB 0x15

#define H #

#define WRITECOMMAND(addr,vala,valb) \
    bl      spi_enable_cs;\
    mov     r5,H WRITEOPCODE;\
    bl      spi_send_byte;\
    mov     r5,H addr;\
    bl      spi_send_byte;\
    mov     r5,H vala;\
    bl      spi_send_byte;\
    mov     r5,H valb;\
    bl      spi_send_byte;\
    bl      spi_disable_cs

#define WRITECOMMAND2(addr,reg) \
    bl      spi_enable_cs;\
    mov     r5,H WRITEOPCODE;\
    bl      spi_send_byte;\
    mov     r5,H addr;\
    bl      spi_send_byte;\
    and     r5,reg,#0xFF;\
    bl      spi_send_byte;\
    ubfx    r5,reg,#8,#8;\
    bl      spi_send_byte;\
    bl      spi_disable_cs




init_mcp23s18:
    push(r0-r5,r14)

    PRINTK("  Using SPI1 channel 0\r\n")
    PRINTK("  Using pin 60 for interrupt\r\n")
    mov     r4,#EXPANDERCS
    mov     r5,#1
    bl      spi_activate_channel

    // when GPIO is input, pin is floating
    // when MCP23s18 INT pin is inactive, it is floating
    //     the pin will go low when active
    //     thus, we will detect "low level" from the GPIO
    //     when INT pin is inactive, GPIO must be high, so we will use a pullup resistor on GPIO
    WRITECOMMAND(IOCON,0b01000100,0b01000100) //opendrain, MIRROR
    WRITECOMMAND(IPOLA,0,0)
    WRITECOMMAND(INTCONA,0,0)

    mov     r5,#0
    bl      spi_activate_channel

    pop(r0-r5,r15)


// r3 = handler to interrupts for pin changed
mcp23s18_register_handler:
    push(r0,r4,r14)
    mov     r0,#60
    mov     r4,#2
    bl      gpio_configure_input_pin
    bl      mcp23s18_get_active_pins // just to clear pending interrupts
    pop(r0,r4,r15)


// RETURN: r9 lower 16bits is bitfield of active pins. 
// Calling this function will clear pending interrupt.
mcp23s18_get_active_pins:
    push(r0-r5,r14)
    ATOMIC_EXEC(r0)
    mov     r4,#EXPANDERCS
    mov     r5,#1
    bl      spi_activate_channel

    bl      spi_enable_cs
    mov     r5,#READOPCODE
    bl      spi_send_byte
    mov     r5,#GPIOA
    bl      spi_send_byte
    bl      spi_send_byte
    mov     r9,r5
    bl      spi_send_byte
    bfi     r9,r5,#8,#8
    bl      spi_disable_cs

    mov     r4,#EXPANDERCS
    mov     r5,#0
    bl      spi_activate_channel
    ATOMIC_END(r0)
    pop(r0-r5,r15)


// r9 = pin number (0..15)
// r10 = MCP23S18_PIN_ACTIVATE / MCP23S18_PIN_DEACTIVATE
mcp23s18_activate_pin:
    push(r0-r6,r14)

    ATOMIC_EXEC(r6)
    mov     r4,#EXPANDERCS
    mov     r5,#1
    bl      spi_activate_channel

    mov     r0,#1
    lsl     r1,r0,r9
    
    ldr     r2,=.pinstatus
    ldr     r3,[r2]
    tst     r10,#MCP23S18_PIN_ACTIVATE
    orreq   r3,r1                       // re-set pint high
    bicne   r3,r1                       // put low
    str     r3,[r2]

    WRITECOMMAND2(OLATA,r3)

    mov     r4,#EXPANDERCS
    mov     r5,#0
    bl      spi_activate_channel
    ATOMIC_END(r6)
    pop(r0-r6,r15)

.pinstatus: .word 0xFF

// r9 = pin number (0..15)
// r10 = MCP23S18_PIN_OUTPUT | MCP23S18_PIN_INPUT | MCP23S18_PIN_PULLUP | MCP23S18_PIN_INTENA
// Output pins will sink current when active.
mcp23s18_configure_pin:
    push(r0-r8,r11,r14)
    ATOMIC_EXEC(r11)

    mov     r0,#1
    lsl     r6,r0,r9

    ldr     r0,=.iodir
    ldr     r1,[r0]
    ldr     r0,=.gppu
    ldr     r2,[r0]
    ldr     r0,=.gpint
    ldr     r3,[r0]

    mvn     r0,r6
    and     r1,r0
    and     r2,r0
    and     r3,r0

    tst     r10,#MCP23S18_PIN_INPUT
    orrne   r1,r6
    biceq   r1,r6
    tst     r10,#MCP23S18_PIN_PULLUP
    orrne   r2,r6
    biceq   r2,r6
    tst     r10,#MCP23S18_PIN_INTENA    
    orrne   r3,r6
    biceq   r3,r6

    mov     r4,#EXPANDERCS
    mov     r5,#1
    bl      spi_activate_channel
    WRITECOMMAND2(IODIRA,r1)
    WRITECOMMAND2(GPPUA,r2)
    WRITECOMMAND2(GPINTENA,r3)
    mov     r4,#EXPANDERCS
    mov     r5,#0
    bl      spi_activate_channel

    ldr     r0,=.iodir
    str     r1,[r0]
    ldr     r0,=.gppu
    str     r2,[r0]
    ldr     r0,=.gpint
    str     r3,[r0]

    ATOMIC_END(r11)
    pop(r0-r8,r11,r15)


.iodir: .word 0
.gppu:  .word 0
.gpint: .word 0

