#include "macros.h"
#include "definitions.h"
#include "swi.h"

.global int_swi
.extern schedule
.extern generate_SGI

int_swi:
    ldr     r13,=SVC_STACK_TOP      // reset the stack everytime for this mode
    push(r14)
    push(r1)

    // We will leave interrupts disabled in SWI for now since most operations
    // we do will disable them anyway
    //push(r0)
    //mrs     r1,SPSR
    //mrs     r0,CPSR
    //and     r1,#0b11000000          // get interrupt status before this was called
    //bic     r0,#0b11000000          // 
    //orr     r0,r1                   // re-eanble interrupts only if it was previously
    //msr     CPSR,r0
    //pop(r0)

    ldr     r1,=swi_table
    ldr     r0,[r1,r0,LSL #2]
    pop(r1)
    blx     r0
    pop(r15)^
    

swi_printf:
    push(r0-r5,r14)
    mov     r4,r1
    bl      debugprint
    pop(r0-r5,r15)

swi_yield:
    push(r0-r3,r14)
    mov     r0,#SCHEDULER_TIMER_INTERRUPT
    bl      generate_SGI
    pop(r0-r3,r15)

// r1 = pin number
// r2 = pointer to handler to get events for pin change
swi_set_gpio_in:
    push(r0-r4,r14)
    mov     r0,r1
    mov     r3,r2
    mov     r4,#3
    bl      gpio_configure_input_pin
    pop(r0-r4,r15)

// r1 = pin number
swi_set_gpio_out:
    push(r0-r1,r14)
    mov     r0,r1
    bl      gpio_configure_output_pin
    pop(r0-r1,r15)

// r1 = pin number
// r2 = value
swi_set_gpio_value:
    push(r0-r3,r14)
    mov     r0,r1
    mov     r3,r2
    bl      gpio_set_pin_status
    pop(r0-r3,r15)

// r1 = handler to interrupts for pin changed
swi_mcp23s18_register:
    push(r3,r14)
    mov     r3,r1
    bl      mcp23s18_register_handler
    pop(r3,r15)

// RETURN: r1 lower 16bits is bitfield of active pins.
swi_mcp23s18_get_active_pins:
    push(r9,r14)
    bl      mcp23s18_get_active_pins
    mov     r1,r9
    pop(r9,r15)

// r1 = pin number (0..15)
// r2 = MCP23S18_PIN_ACTIVATE / MCP23S18_PIN_DEACTIVATE
swi_mcp23s18_activate_pin:
    push(r9-r10,r14)
    mov     r9,r1
    mov     r10,r2
    bl      mcp23s18_activate_pin
    pop(r9-r10,r15)

// r1 = pin number (0..15)
// r2 = MCP23S18_PIN_OUTPUT | MCP23S18_PIN_INPUT | MCP23S18_PIN_PULLUP | MCP23S18_PIN_INTENA
swi_mcp23s18_configure_pin:
    push(r9-r10,r14)
    mov     r9,r1
    mov     r10,r2
    bl      mcp23s18_configure_pin
    pop(r9-r10,r15)




swi_table:
.word 0 // reserved
.word swi_printf
.word swi_yield
.word swi_set_gpio_in
.word swi_set_gpio_out
.word swi_set_gpio_value
.word swi_mcp23s18_register
.word swi_mcp23s18_get_active_pins
.word swi_mcp23s18_activate_pin
.word swi_mcp23s18_configure_pin
