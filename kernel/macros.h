.extern debugprint
.extern debugdumpmem

#define push(a...) stmdb r13!,{a}

#define pop(a...) ldmia r13!,{a}

#define WAIT(a)\
    push(r0); \
    ldr r0,=a; \
98764:subs r0,#1; \
    bne 98764b; \
    pop(r0); \

#define STALL() 98765:b 98765b

#define PRINTREG(reg)\
    push(r1,r14); \
    mov r1,reg; \
    bl  debugprintRegister; \
    pop(r1,r14)

#define PRINTMEM2(addr,count)\
    push(r0-r1,r14); \
    mov r0,addr; \
    ldr r1,=count; \
    bl  debugdumpmem; \
    pop(r0-r1,r14)

#define PRINTMEM(addr,count)\
    push(r0-r1,r14); \
    ldr r0,=addr; \
    ldr r1,=count; \
    bl  debugdumpmem; \
    pop(r0-r1,r14)


#define PRINTK(STR)\
    push(r4,r14); \
    adr r4,2421f; \
    bl  debugprint; \
    b   2422f; \
    2421: .ASCIZ STR; \
    .ALIGN 4; \
    2422: pop(r4,r14)

#define ATOMIC_EXEC(scratchregister) \
/*    push(r2);\
    mrs scratchregister,CPSR;\
    orr r2,scratchregister,#0b10000000;\
    msr CPSR,r2;\
    pop(r2)*/

#define ATOMIC_END(scratchregister) //mrs scratchregister,CPSR

