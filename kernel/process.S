#include "definitions.h"
#include "macros.h"

.global loadProgram
.global schedule
.global schedule2
.extern kernelSize
.extern virt2phys
.extern processAlloc
.extern pageAlloc
.extern returnFromInterrupt
.extern createPageTablesForProcess
.global initProcessManager

programsAddressTable: 
.rept 512
.byte 0
.endr

initProcessManager:
    push(r0-r3,r14)
    //Clear the process list
    ldr     r0,=KERNEL_PROCESS_LIST_START
    ldr     r1,=KERNEL_PROCESS_LIST_END
    ldr     r3,=KERNEL_PROCESS_ENTRY_SIZE
    mov     r2,#0
1:  str     r2,[r0]
    add     r0,r3
    cmp     r0,r1
    bne     1b

    // There was a bug in qemu1.6.0 in target-arm/helper.c at line 343. I had to change "cp15.c13_fcse"
    // for "cp15.c13_context" because any updates to CONTEXTIDR would not be set.
    mov     r1,#0x0
    dmb
    mcr     p15,0,r1,c13,c0,1           // set current ASID to 0
    isb

    // read the program table of content
    ldr r5,=programsAddressTable
    ldr r6,=PROGRAM_ADDRESS_IN_EMMC
    bl  emmc_read_sector
    //PRINTMEM(programsAddressTable,32)

    pop(r0-r3,r15)


scheduleSWHandler:
    push(r0,r1)
    mrc     p15,0,r1,c13,c0,1           // get current ASID
    cmp     r1,#0
    beq     returnFromInterrupt
    ldr     r0,=KERNEL_PROCESS_LIST_START
    add     r0,r0,r1,LSL #KERNEL_PROCESS_ENTRY_SIZE_SHIFT
    mov     r1,#1
    str     r1,[r0,#0x08]
    pop(r0,r1)
    b       schedule2


schedule2:
    stmdb   r13,{r0-r14}^
    sub     r13,#(15*4)         // push^ will not update r13
    mrs     r0,SPSR
    push(r0)

    // We will change to SVC mode temporirly just to get the r13_svc and r14_svc and store them on stack
    mrs     r0,CPSR
    bic     r1,r0,#0b11111
    orr     r1,#0b10011      
    msr     CPSR,r1         // switch to supervisor mode to save r13_svc and r14_svc
    mov     r1,r13          
    mov     r2,r14
    msr     CPSR,r0         // switch back to original mode before pushing
    push(r1,r2)             // push r13_svc and r14_svc. done here because in SVC mode, we would have used the SVC stack.
    // At this point, whole context is saved on stack

    // get the current running thread
    ldr     r2,=KERNEL_PROCESS_LIST_START
    mrc     p15,0,r1,c13,c0,1           // get current ASID
    
    mov     r4,r1   // r4 will be used later because it holds the "current" index
    cmp     r1,#0   
    beq     noQuantumCount          //no quantum count for task 0

    //decrease task quantum counter
    add     r5,r2,r1,LSL #KERNEL_PROCESS_ENTRY_SIZE_SHIFT
    ldr     r3,[r5,#0x08]
    subs    r3,#1
    ldreq   r3,=TASK_QUANTUM_COUNTER
    str     r3,[r5,#0x08]    
    bne     noTaskSwitch                   // count not elaped, not the time to change task yet
noQuantumCount:
    // determine which is the next one to run
    ldr     r3,=KERNEL_PROCESS_LIST_SIZE+1
1:  subs    r3,#1
    beq     sameTaskAgain          // we will exit before we come back to the current one
    add     r1,#1
    and     r1,#KERNEL_PROCESS_LIST_SIZE_MASK       // to wrap around overflow
    cmp     r1,#0                   // skip entry #0
    moveq   r1,#1
    ldr     r5,[r2,r1,LSL #KERNEL_PROCESS_ENTRY_SIZE_SHIFT]
    cmp     r5,#0                           // first fieldin table will be the L1 pointer. Should not be null
    beq     1b
    add     r5,r2,r1,LSL #KERNEL_PROCESS_ENTRY_SIZE_SHIFT       // r5 = pointer to process entry in table
    // At this point, r1 = current ASID

    cmp     r4,#0
    beq     20f

    //store context: save r13
    add     r0,r2,r4,LSL #KERNEL_PROCESS_ENTRY_SIZE_SHIFT
    str     r13,[r0,#4]

    // if we are changing context, we need to clear any exclusive access because
    // we might have interrupted in between a ldrex and strex, and we could be resuming
    // in the middle of another pair
    clrex                       

20:
    // load new page table
    ldr     r0,[r5]
    mcr     p15,0,r0,c2,c0,0

    // set new running ASID so that we wont have to flush the TLB
    dmb                             // make sure all memory access are over before changing ASID
    mcr     p15,0,r1,c13,c0,1       
    isb

    //load r13_irq
    ldr     r13,[r5,#4]

sameTaskAgain:
noTaskSwitch:
    // Now we will change mode to SVC temporarily just to restore r13_svc and r14_svc
    pop(r2,r3)             // pop r13_svc and r14_svc
    mrs     r0,CPSR
    bic     r1,r0,#0b11111
    orr     r1,#0b10011      
    msr     CPSR,r1         // switch to supervisor mode to save r13_svc and r14_svc
    mov     r13,r2
    mov     r14,r3
    msr     CPSR,r0         // switch back to original mode

    // now restore spsr and user context on stack
    pop(r0)            
    msr     SPSR,r0
    ldmia   r13,{r0-r14}^
    add     r13,#(15*4)         // pop^ will not update r13
    b       returnFromInterrupt


// r0 = L1 table address for process
// returns r0 = address of process entry
addProcessInList:
    push(r1,r2,r3,r4,r5,r14)
    mov     r5,#0
    ldr     r1,=KERNEL_PROCESS_LIST_START+KERNEL_PROCESS_ENTRY_SIZE // skip the first entry. It is reserved
    ldr     r4,=KERNEL_PROCESS_ENTRY_SIZE
    ldr     r2,=KERNEL_PROCESS_LIST_END
1:  add     r5,#1
    ldr     r3,[r1]
    cmp     r3,#0
    beq     foundEmptyProcessEntry
    add     r1,r4
    cmp     r1,r2
    bne     1b
    //TODO: should return an error here

foundEmptyProcessEntry:
    str     r0,[r1]
    mov     r0,r1

    mcr     p15,0,r5,c8,c7,2    // clrear TLB entries associated to that ASID 
    pop(r1,r2,r3,r4,r5,r15)


//r4 = program ID
//returns r0=meta page physical address
loadProgram:
    push(r2,r4,r5,r6,r7,r8,r14)
    cmp     r4,#0       
    moveq   r15,r14 // if r4 is zero, return

    mov     r2,#0
    ldr     r1,=programsAddressTable
1:  ldr     r3,[r1],#4
    subs    r4,#1
    addne   r2,r3
    bne     1b
    ldr     r5,=PROGRAM_ADDRESS_IN_EMMC+1
    add     r5,r2,LSR #9 // divide by 512, the sector size
    mov     r4,r3
    // At this point: r5=byte index in mmc, r4=size (will be a multiple of 512)
   
    bl      createPageTablesForProcess 
    mov     r1,r0                       //r0 contains the base of the L1 table from createPageTablesForProcess
                                        // At this point, r2= ptocess IRQ stack top

    // create process
    bl      addProcessInList            
    mov     r8,r0
    
    ldr     r0,=TASK_QUANTUM_COUNTER
    str     r0,[r8,#0x8]                // store the task quantum counter
    // prepare initial context in process stack
    ldr     r0,=4096-4
    add     r2,r0
    ldr     r0,=PROCESS_CODE_START
    str     r0,[r2],#-4                 // push program entry point as the return from IRQ
    mov     r0,#0
    str     r0,[r2],#-4                 // r14
    mvn     r0,#3                       // stack starts at 0xFFFFFFFC and will decrement because it is at the end of addressing space
    str     r0,[r2],#-4                 // r13
    mov     r0,#0
    str     r0,[r2],#-4                 // r12
    str     r0,[r2],#-4                 // r11
    str     r8,[r2],#-4                 // r10 put r8 (L1 table) to debug
    str     r0,[r2],#-4                 // r9
    str     r0,[r2],#-4                 // r8
    str     r0,[r2],#-4                 // r7
    str     r0,[r2],#-4                 // r6
    str     r0,[r2],#-4                 // r5
    str     r0,[r2],#-4                 // r4
    str     r0,[r2],#-4                 // r3
    str     r0,[r2],#-4                 // r2 
    str     r0,[r2],#-4                 // r1
    str     r0,[r2],#-4                 // r0 
    mov     r0,#0b10000                 // CPSR: user mode
    str     r0,[r2],#-4                 
    mov     r0,#0
    str     r0,[r2],#-4                 //r14_svc
    str     r0,[r2],#-4                 //r13_svc

    ldr     r0,=IRQ_STACK_TOP-(19*4)
    str     r0,[r8,#0x4]                // store the r13_irq

    // at this point: r1=L1 table, r4=number of 512bytes blocks for program, r5=byte address in eMMC
    bl      growProcessStack


    // Allocate program memory
    ldr     r6,=(4096-1)
    add     r6,r4           // r4 is already set to size of image
    lsr     r6,#12              //r6 = page count rounded up

    bl      processAlloc
    mov     r7,r2               // virtual address of 1st page allocated to process
    subs    r6,#1
    beq     2f
1:  bl      processAlloc
    subs    r6,#1
    bne     1b   
2:

    ldr     r0,=511
    add     r0,r4
    lsr     r0,#9       //r0 = number of sectors for program, rounded up
    mov     r2,r7       //virtual address to where to load it 
    mov     r3,r5       // emmc address
    bl      copyProgram // r1 was set to L1 table previously, we need it here.

    mov     r0,r8
    pop(r2,r4,r5,r6,r7,r8,r15) // ret



// copy the program to memory in chunks of 4k.
// r0 = number of sectors for program
// r2 = virtual address to load program at
// r3 = emmC address
// r1 = L1 page table address
copyProgram:
    push(r5-r9,r14)
    ldr     r7,=0x200
    mov     r8,r2
    mov     r9,r1

1:  mov     r1,r9
    mov     r2,r8
    bl      virt2phys           //  r2 contains the vaddr to load to
    movs    r5,r2
    beq     2f                  //if r2 was zero, then get out
    mov     r6,r3
    bl      emmc_read_sector
    add     r8,r7
    add     r3,#1    
    subs    r0,#1
    bne     1b
    pop(r5-r9,r15)
2:  PRINTK("Problem using virt2phys in copyProgram")
    STALL()
