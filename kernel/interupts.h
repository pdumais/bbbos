.extern entryPoint
.extern int_undefined
.extern int_data_abort
.extern int_instruction_fetch_abort
.extern int_swi
.extern int_IRQ

#define IDT_RESET                      ldr  r15,=entryPoint
#define IDT_UNDEFINED_INSTRUCTION      ldr  r15,=int_undefined
#define IDT_SWI                        ldr  r15,=int_swi
#define IDT_INSTRUCTION_FETCH_ABORT    ldr  r15,=int_instruction_fetch_abort
#define IDT_DATA_ABORT                 ldr  r15,=int_data_abort
#define IDT_RESERVED                   .word 0
#define IDT_IRQ                        ldr  r15,=int_IRQ
#define IDT_FIRQ                       ldr  r15,=int_undefined



#define HANDLER_ADDRESS 0
#define HANDLER_ASID 4
#define HANDLER_L1TABLE 8
#define HANDLER_RESERVED 12
#define HANDLERTABLE(n) \
    .rept n; \
    .word 0; \ 
    .word 0; \ 
    .word 0; \ 
    .word 0; \ 
    .endr

