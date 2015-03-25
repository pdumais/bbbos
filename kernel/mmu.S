#include "definitions.h"
#include "macros.h"
#include "mmu.h"

.global initMMU
.global int_data_abort
.global int_instruction_fetch_abort
.global virt2phys
.global pageAlloc
.global createPageTablesForProcess
.global processAlloc
.global growProcessStack

.extern failFromInterrupt

#define DOMAINS 0b0111

// no need for permissions on kernel pages, we are in manager domain
#define KERNEL_PAGE_TABLE           L1_TYPE_PAGETABLE
#define KERNEL_SECTION_CODE         SECTION_CB | L1_TYPE_SECTION
#define KERNEL_SECTION_PERIPHERALS  L1_TYPE_SECTION | SECTION_EXECUTE_NEVER
#define KERNEL_PAGE_PERIPHERALS     L1_TYPE_SMALLPAGE | PAGE_EXECUTE_NEVER
#define KERNEL_PAGE_SRAM            PAGE_CB | L1_TYPE_SMALLPAGE
#define KERNEL_PAGE_HEAP_FREE       PAGE_CB | PAGE_NG
#define KERNEL_PAGE_HEAP_INUSE      KERNEL_PAGE_HEAP_FREE | L1_TYPE_SMALLPAGE

#define PROCESS_PAGE_TABLE          L1_TYPE_PAGETABLE | (1<<DOMAIN_BIT_INDEX)
#define PROCESS_SECTION_KERNEL_CODE SECTION_AP_RWNO | SECTION_CB | L1_TYPE_SECTION | (1<<DOMAIN_BIT_INDEX) 
#define PROCESS_SECTION_PERIPHERALS SECTION_AP_RWNO | L1_TYPE_SECTION | SECTION_EXECUTE_NEVER | (1<<DOMAIN_BIT_INDEX)
#define PROCESS_PAGE_PERIPHERALS    PAGE_AP_RWNO | L1_TYPE_SMALLPAGE | PAGE_EXECUTE_NEVER
#define PROCESS_PAGE_SRAM           PAGE_AP_RWNO | L1_TYPE_SMALLPAGE
#define PROCESS_PAGE_ENTRY_HEAP     PAGE_AP_RWRW | PAGE_CB | L1_TYPE_SMALLPAGE | PAGE_NG 
#define PROCESS_PAGE_ENTRY_STACK    PAGE_AP_RWRW | PAGE_CB | L1_TYPE_SMALLPAGE | PAGE_EXECUTE_NEVER | PAGE_NG
#define PROCESS_SECTION_UNMAPPED 0
#define PROCESS_PAGE_UNMAPPED 0
#define KERNEL_PAGE_UNMAPPED 0
#define KERNEL_SECTION_UNMAPPED 0 


#define CREATESECTIONS(start,end,flag,l1base,physicaladdress) \
    ldr     r0,=start;\
    ldr     r1,=end;\
    ldr     r3,=flag;\
    mov     r2,l1base;\
    ldr     r4,=physicaladdress;\
    bl      createSections;

#define CREATEKERNELPAGETABLES(start,end,flag)\
    ldr     r0,=start;\
    ldr     r1,=end;\
    ldr     r3,=flag;\
    bl      createKernelPageTables;

#define CREATEPEAGEENTRIES(start,end,startphysicaladdress,flag,l1base)\
    ldr     r0,=start;\
    ldr     r1,=end;\
    ldr     r2,=startphysicaladdress;\
    ldr     r3,=flag;\
    mov     r4,l1base;\
    bl      createPageEntries;

#define CREATEPROCESSPAGETABLES(start,end,flags,l1base)\
    ldr     r0,=start;\
    ldr     r1,=end;\
    mov     r2,l1base;\
    ldr     r3,=flags;\
    bl      createProcessPageTables;


// r0 = first page
// r1 = last page
// r2 = l1 base address
// r3 = flags
createProcessPageTables:
    push(r4-r8,r14)
    ldr     r4,=1024
    mov     r7,r0
    
1:  bl      pageAlloc 
    cmp     r0,#0
    beq     4f
    orr     r6,r0,r3
    mov     r5,#4
2:  str     r6,[r2,r7, LSL #2]
    add     r6,r4 // trying to solve boot problem
//    add     r0,r4
    add     r7,#1
    cmp     r7,r1
    bhi     3f    
    subs    r5,#1
    bne     2b
    b       1b
3:
    pop(r4-r8,r15)
4:
    PRINTK("ERROR: no more memory while creating process tables\r\n")
    1:b 1b




// r0 = first block
// r1 = last block
// r2 = L1 address
// r3 = flags
// r4 = physical address
createSections:
    push(r5,r6,r14)
    ldr     r6,=(1024*1024)
1:  orr     r5,r4,r3
    add     r4,r6
    str     r5,[r2,r0,LSL #2]
    add     r0,#1
    cmp     r0,r1
    bls     1b  
    pop(r5,r6,r15)


// r0 = first block
// r1 = last block
// r3 = flags
createKernelPageTables:
    push(r2,r4,r5,r14)
    ldr     r2,=KERNEL_LEVEL1_PAGE_TABLE
    ldr     r4,=KERNEL_LEVEL2_PAGE_TABLE
1:  add     r5,r4,r0,LSL #10   // *1024 because each table are 1k wide
    orr     r5,r5,r3
    str     r5,[r2,r0,LSL #2]
    add     r0,#1
    cmp     r0,r1
    bls     1b
    pop(r2,r4,r5,r15)

// r0 = first page
// r1 = last page
// r2 = physical address
// r3 = flags
// r4 = L1 address
createPageEntries:
    push(r5,r6,r7,r14)
    ldr     r7,=0x3FF
    // convert page number to L1 entry (pagenum / 256 since there are 256 pages per L1 entry)
1:  lsr     r5,r0,#8
    and     r6,r0,#0xFF
    add     r5,r4,r5,LSL #2     // multiply by 4 to get offset of entry and add L1 base address
    ldr     r5,[r5]             // now r5 = L2 table of the page
    tst     r5,#0b10            // is the page refering to a page table? 
    bne     2f
    bic     r5,r7            // clear flags in descrptor to retrieve addr only
    add     r5,r5,r6,LSL #2     // r5 = entry of page
 
    orr     r6,r2,r3
    str     r6,[r5]
    add     r2,#4096
    add     r0,#1
    cmp     r0,r1
    bls     1b

    pop(r5,r6,r7,r15)
2: 
    PRINTK("ERROR: Trying to set page on a section")
    1:b 1b


initMMU:
    push(r14)
    PRINTK("Initializing MMU\r\n")
    ldr     r8,=KERNEL_LEVEL1_PAGE_TABLE

    CREATESECTIONS(0x000,0x1FF,KERNEL_SECTION_CODE,r8,0)
    CREATESECTIONS(0x200,0x401,KERNEL_SECTION_UNMAPPED,r8,0)
    CREATEKERNELPAGETABLES(0x402,0x402,KERNEL_PAGE_TABLE)
    CREATESECTIONS(0x403,0x43F,KERNEL_SECTION_UNMAPPED,r8,0)
    CREATESECTIONS(0x440,0x56F,KERNEL_SECTION_PERIPHERALS,r8,0x44000000)
    CREATESECTIONS(0x570,0x7FF,KERNEL_SECTION_UNMAPPED,r8,0)
    CREATESECTIONS(0x800,0x809,KERNEL_SECTION_CODE,r8,0x80000000)
    CREATEKERNELPAGETABLES(0x80A,0xBFF,KERNEL_PAGE_TABLE)
    CREATESECTIONS(0xC00,0xEFF,KERNEL_SECTION_UNMAPPED,r8,0)
    CREATEKERNELPAGETABLES(0xF00,0xFFF,KERNEL_PAGE_TABLE)

    CREATEPEAGEENTRIES(0x40200,0x402EF,0x100E4000,KERNEL_PAGE_UNMAPPED,r8)
    CREATEPEAGEENTRIES(0x402F0,0x402FF,0x402F0000,KERNEL_PAGE_SRAM,r8)  // SRAM
    CREATEPEAGEENTRIES(0x80A00,0xBFFFF,0x80A00000,KERNEL_PAGE_HEAP_FREE,r8)  // heap
    CREATEPEAGEENTRIES(0xF0000,0xF0000,KERNEL_PHYSICAL_IRQ_STACK,KERNEL_PAGE_HEAP_INUSE,r8)
    CREATEPEAGEENTRIES(0xF0001,0xFFFFF,0x0,KERNEL_PAGE_UNMAPPED,r8)  // user-space stacks

    // CP15, r2: Set the level1 base address
    ldr     r0,=KERNEL_LEVEL1_PAGE_TABLE
    mcr     p15,0,r0,c2,c0,0
    // CP15, r3: Domain 0=manager, domain1=client, all others are zero
    ldr     r0,=DOMAINS
    mcr     p15,0,r0,c3,c0,0

    // disable FCSE
    mov     r0,#0
    mrc     p15,0,r0,c13,c0,0

    // CP15, r1: enable mmu
    mrc     p15,0,r0,c1,c0,0    // use read/modify/write to not clear registers that are set on reset
    orr     r0,#0b100001
    mcr     p15,0,r0,c1,c0,0

    // Use ttbr0 only. No need for TTBR1, so set TTBCR to 0
    mov     r0,#0
    mcr     p15,0,r0,c2,c0,2
    pop(r15)


// reserves a free page (marks it as in-use)
// returns r0 = physical address of page. 0 if no more memory
// Note: This is thread safe
pageAlloc:
    push(r1,r3,r4,r14)
1:  ldr     r0,=KERNEL_LEVEL2_PAGE_TABLE+(4*(KERNEL_RESERVED_END/4096)) //1st entry of available ram in L2 tables
    ldr     r4,=KERNEL_LEVEL2_PAGE_TABLE+(KERNEL_LEVEL2_PAGE_TABLE_SIZE*4096)
2:  ldr     r1,[r0]
    cmp     r0,r4
    beq     nopages         // exit with error if end is reached
    tst     r1,#3           // check if page is free
    addne   r0,#4
    bne     2b

    // A page was found, mark it as in-use.
    ldrex   r1,[r0]
    tst     r1,#3           // check if page is free again
//TODO: should cancel ldrex
    bne     1b
    orr     r1,r1,#2
    strex   r3,r1,[r0]
    cmp     r3,#0
    bne     1b

    // return the physical address
    ldr     r3,=0xFFFFF000
    and     r0,r1,r3
    pop(r1,r3,r4,r15)
nopages:
    PRINTK("ERROR: No memory left with pageAlloc\r\n")
    mov     r0,#0
    pop(r1,r3,r4,r15)



// Will allocate n pages that all all consecutive in physical memory and are alligned on a 16k boundary
// r7 = number of pages
// returns ro = physical address of begining of buffer
// NOTICE: This function is NOT thread safe so far!!!
pageAllocConsecutive:
    push(r1,r2,r3,r4,r6,r14)

    // Find consecutive pages but don't mark them right away
    mov     r2,#0
    mvn     r4,#0b111
1:  ldr     r0,=KERNEL_LEVEL2_PAGE_TABLE+(4*(KERNEL_RESERVED_END/4096)) //1st entry of available ram in L2 tables
    ldr     r3,=KERNEL_LEVEL2_PAGE_TABLE+(KERNEL_LEVEL2_PAGE_TABLE_SIZE*1024) // end of L2 tables
2:  ldr     r1,[r0],#4
    cmp     r0,r3
    beq     nopages_1       // exit with error if end is reached
    tst     r1,#3           // check if page is free
    movne   r2,#0           // if that page is not free, restart counter
    andne   r0,r4           // if that page is not free jump to next 16k
    addne   r0,#16
    bne     2b
    add     r2,r2,#1        // A page was found, increase counter
    cmp     r2,r7           // is the count = to number of pages requested?
    bne     2b              // not yet, so find some more
    // at this point, all consecutive pages were found. r0 point to last descriptor+4
    // so convert r0 to the initial address
    sub     r0,r0,r7,LSL #2     // r0 = r0-(count*4)
    ldr     r4,[r0]             // extract physical address from descriptor
    lsr     r4,#12              // clear 12 lower bits 
    lsl     r4,#12              // now r4 contains the physical address that we need.

    // At this point, we found a valid range, but did not reserve it yet. So do it now
1:  ldr     r1,[r0]
    orr     r1,r1,#2
    str     r1,[r0],#4
    subs    r7,r7,#1
    bne     1b

    // return the physical address
    mov     r0,r4
    pop(r1,r2,r3,r4,r6,r15)
nopages_1:
    mov     r0,#0
    pop(r1,r2,r3,r4,r6,r15)


// returns r0=physical location of L1 table
//         r2=physical location of IRQ stack
createPageTablesForProcess:
    push(r1,r3-r8,r14)


    // Allocate 16k of physical memory for L1 page table
    mov     r7,#4
    bl      pageAllocConsecutive
    mov     r8,r0

    // create sections in L1 table (see documentation for process page layout)
    CREATESECTIONS(0x000,0x1FF,PROCESS_SECTION_KERNEL_CODE,r8,0)
    CREATEPROCESSPAGETABLES(0x200,0x401,PROCESS_PAGE_TABLE,r8)  // process code
    CREATEPROCESSPAGETABLES(0x402,0x402,PROCESS_PAGE_TABLE,r8)  // SRAM
    CREATESECTIONS(0x402,0x43F,PROCESS_SECTION_UNMAPPED,r8,0)
    CREATESECTIONS(0x440,0x56F,PROCESS_SECTION_PERIPHERALS,r8,0x44000000) // peripherals
    CREATESECTIONS(0x570,0x7FF,PROCESS_SECTION_UNMAPPED,r8,0)
    CREATESECTIONS(0x800,0xBFF,PROCESS_SECTION_KERNEL_CODE,r8,0x80000000)
    CREATESECTIONS(0xC00,0xEFF,PROCESS_SECTION_UNMAPPED,r8,0)
    CREATEPROCESSPAGETABLES(0xF00,0xFFF,PROCESS_PAGE_TABLE,r8) // process stack

    CREATEPEAGEENTRIES(0x20000,0x401FF,0,PROCESS_PAGE_UNMAPPED,r8) 
    CREATEPEAGEENTRIES(0x40200,0x402EF,0,PROCESS_PAGE_UNMAPPED,r8) 
    CREATEPEAGEENTRIES(0x402F0,0x402FF,0x402F0000,PROCESS_PAGE_SRAM,r8)
    CREATEPEAGEENTRIES(0xF0000,0xFFFFF,0,PROCESS_PAGE_UNMAPPED,r8)


    //Allocate a stack page for IRQ
    bl      pageAlloc
    cmp     r0,#0
    beq     no_irq_stack_page
    mov     r1,r8
    ldr     r2,=0xF0000000
    bl      virt2phys
    ldr     r3,=PROCESS_PAGE_ENTRY_STACK
    mov     r2,r0 // we will return r2
    orr     r0,r0,r3
    str     r0,[r1] // r1 was the address of the L2 entry for the virtual address after calling virt2phys

    // r8 is the address of the L1 table. We will return that.
    mov     r0,r8

    pop(r1,r3-r8,r15)
no_irq_stack_page:
    PRINTK("Failed allocating stack page for IRQ")
    b       failFromInterrupt    






// Translate virtual addr to physical addr according to L1 table
// r1 = L1 table
// r2 = virtual address
// returns  r2=physical address, 0 if memory is not allocated. so dont request a virt addr that should map to 0.
//          r1=physical address of L2 entry
virt2phys:
    push(r3,r4,r14)
    ldr     r3,=0xFFF
    and     r4,r2,r3
    lsr     r3,r2,#20   // convert virtual addr L1 offset (addr >> 20 *4
    lsl     r3,r3,#2   
    add     r1,r1,r3
    ldr     r1,[r1]
    bic     r1,#0xFF    //r3 =address of L2 page.
    ubfx    r3,r2,#12,#8
    add     r1,r1,r3, LSL #2
    ldr     r2,[r1]
    tst     r2,#0b11     // if page is not mapped, return 0
    moveq   r2,#0
    lsr     r2,#12          // clear 12 lowest bits
    lsl     r2,#12
    orr     r2,r4
    pop(r3,r4,r15)


// Reserves a page in process memory. This memory is allocated in the process code/data L2 tables
// r1 = L1 table of process
// return: r2 = virtual address
processAlloc:
    push(r1,r3,r4,r5,r14)
    mov     r2,#0
    mov     r5,r1
    //find first empty page in process
    ldr     r3,=4096
    ldr     r0,=PROCESS_CODE_START
    ldr     r4,=PROCESS_CODE_END
1:  cmp     r0,r4
    beq     no_virtual_mem_free 
    mov     r2,r0
    mov     r1,r5
    bl      virt2phys
    cmp     r2,#0       // continue until we find a free page. It must be 0, otherwise, it is not free
    addne   r0,r3
    bne     1b

    mov     r2,r0

    //allocate a page
    bl      pageAlloc
    cmp     r0,#0
    beq     no_virtual_mem_free

    //set process empty page's physical address to the newly allocated page
    ldr     r3,=PROCESS_PAGE_ENTRY_HEAP
    orr     r0,r0,r3    
    str     r0,[r1] // r1 was the address of the L2 entry for the virtual address after calling virt2phys
    // at this point, r2 is the virtual address

no_virtual_mem_free:
    pop(r1,r3,r4,r5,r15)


// Reserves an extra page in process stack. stack grows down
// r1 = L1 table of process
// return: r2 = virtual address
growProcessStack:
    push(r1,r3,r4,r5,r14)
    mov     r2,#0
    mov     r5,r1

    ldr     r3,=4096
    ldr     r0,=PROCESS_STACK_TOP
    ldr     r4,=PROCESS_STACK_BOTTOM
1:  cmp     r0,r4
    moveq   r2,#0
    beq     no_stack_mem_free 
    mov     r2,r0
    mov     r1,r5
    bl      virt2phys
    cmp     r2,#0       // continue until we find a free page. It must be 0, otherwise, it is not free
    subne   r0,r3
    bne     1b
    mov     r2,r0


    //allocate a page
    bl      pageAlloc
    cmp     r0,#0
    moveq   r2,#0
    beq     no_stack_mem_free

    //set process empty page's physical address to the newly allocated page
    ldr     r3,=PROCESS_PAGE_ENTRY_STACK
    orr     r0,r0,r3    
    str     r0,[r1] // r1 was the address of the L2 entry for the virtual address after calling virt2phys
    // at this point, r2 is the virtual address
no_stack_mem_free:
    pop(r1,r3,r4,r5,r15)





int_data_abort:
    push(r14)
    push(r0-r3)
    clrex                           // we will use ldrex/strex in here, this is in case we interrupted in the middle of a pair
    mrc     p15, 0, r0, c5, c0, 0
    mrc     p15, 0, r1, c6, c0, 0

    // When getting a translation error. It could be because
    // a process tried to access stack space that is not allocated.
    // The stack is lazily allocated so we must grow it.
    ldr     r2,=0b10000001111
    and     r2,r0,r2
    cmp     r2,#0b111                   // is this a translation fault?
    bne     2f
    ldr     r3,=PROCESS_STACK_BOTTOM    // is it for an address that should be in stack?
    cmp     r1,r3
    blo     2f

    mov     r0,#1
    add     r2,r1,r0, LSL #12           //check if r1+4096 is mapped (so that this is a sequential access)
    mrc     p15,0,r1,c2,c0,0
    bl      virt2phys                                    
    cmp     r2,#0
    beq     2f

    mrc     p15,0,r1,c2,c0,0            // grow the stack
    bl      growProcessStack
    cmp     r2,#0
    beq     3f

    pop(r0-r3)
    pop(r14)
    subs     r15,r14,#0x08

2:
    PRINTK("UNKNOWN Data abort\r\n")
    mrc     p15, 0, r1, c6, c0, 0
    PRINTREG(r1)
3:  pop(r0-r3)
    pop(r14)
    sub     r14,#8
    PRINTREG(r14)
//PRINTMEM(0x20000000,32)
    b       failFromInterrupt

int_instruction_fetch_abort:
    mrc p15,0,r0,c5,c0,1
    mrc p15,0,r1,c6,c0,2
    PRINTREG(r1)
    PRINTK("Page fault (instruction)\r\n")
    STALL()
    
