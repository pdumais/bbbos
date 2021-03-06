#include "definitions.h"
#include "macros.h"

.global init_emmc
.global emmc_read_sector

#define MMC_CMD1   ((1<<24)|(2<<16))
#define MMC_CMD6   ((6<<24)|(2<<16))
#define MMC_CMD7   ((7<<24)|(2<<16))
#define MMC_CMD16  ((16<<24)|(2<<16))
#define MMC_CMD17  ((17<<24)|(2<<16)|(1<<4)|(1<<19)|(1<<20)|(1<<21)|(0<<22))

#define SD_SYSCONFIG 0x110
#define SD_SYSSTATUS 0x114
#define SD_CSRE      0x124
#define SD_SYSTEST   0x128
#define SD_CON       0x12C
#define SD_PWCNT     0x130
#define SD_SDMASA    0x200
#define SD_BLK       0x204
#define SD_ARG       0x208
#define SD_CMD       0x20C
#define SD_RSP10     0x210
#define SD_RSP32     0x214
#define SD_RSP54     0x218
#define SD_RSP76     0x21C
#define SD_DATA      0x220
#define SD_PSTATE    0x224
#define SD_HCTL      0x228
#define SD_SYSCTL    0x22C
#define SD_STAT      0x230
#define SD_IE        0x234
#define SD_ISE       0x238
#define SD_AC12      0x23C
#define SD_CAPA      0x240
#define SD_CUR_CAPA  0x248
#define SD_FE        0x250
#define SD_ADMAES    0x254
#define SD_ADMASAL   0x258
#define SD_ADMASAH   0x25C
#define SD_REV       0x2FC


//Section 18.4.3.2 illustrates a way to detect which type of card is attached.
// But we dont need none of that since we know that we have eMMC attached on MMC1
// This code will obviously not be portable because of that assumpttion. But 
// I just wanna make it work on the BeagleBone black with eMMC.
// most of the information was found at:   https://github.com/paulquevedo/beaglebone/blob/master/sdhc.c

init_emmc:
    push(r0-r4,r14)

    // uboot already has enabled the device and set the clock
    // prcm_init_mmc

    ldr     r0,=MMC1
    mov     r1,#2
    str     r1,[r0,#SD_SYSCONFIG]
1:  ldr     r1,[r0,#SD_SYSSTATUS]
    tst     r1,#1
    beq     1b

    // reset data lines
    ldr     r1,[r0,#SD_SYSCTL]
    ldr     r2,=(1<<24)
    orr     r1,r2
    str     r1,[r0,#SD_SYSCTL]
1:  ldr     r1,[r0,#SD_SYSCTL]
    ands    r1,r2
    bne     1b

    // Capabilities
    ldr     r1,=(1<<24)         // enable 3.3v
    str     r1,[r0,#SD_CAPA]

    ldr     r1,=(1<<1)|(7<<9)
    str     r1,[r0,#SD_HCTL]
    orr     r1,#(1<<8)  // voltage select needs to be selected before setting this bit
    str     r1,[r0,#SD_HCTL]
1:  ldr     r1,[r0,#SD_HCTL]
    tst     r1,#(1<<8)
    beq     1b

    // enable internal clock
    ldr     r1,[r0,#SD_SYSCTL]
    orr     r1,#1
    str     r1,[r0,#SD_SYSCTL]
    orr     r1,#(2<<6)   // TODO: Not sure about this one, should change speed
    str     r1,[r0,#SD_SYSCTL]
1:  ldr     r1,[r0,#SD_SYSCTL]
    tst     r1,#1
    beq     1b
    ldr     r2,=(1<<2)|(14<<16) // set timeout to 2^27
    orr     r1,r2
    str     r1,[r0,#SD_SYSCTL]

    // enable status bits to be set by module
    mov     r1,#1
    str     r1,[r0,#SD_IE]

    ldr     r2,[r0,#SD_CON]
    orr     r2,#0b10
    str     r2,[r0,#SD_CON]
    mov     r1,#0
    str     r1,[r0,#SD_CMD]     //CMD0 Go Idle
1:  ldr     r1,[r0,#SD_STAT]    
    cmp     r1,#1
    bne     1b
    bic     r2,#0b10
    str     r2,[r0,#SD_CON]     // clear init bit
    str     r1,[r0,#SD_STAT]

    // enable status bits.
    ldr     r1,=(0xFFFF0000) | 1 | (1<<1) | (1<<4) | (1<<5)
    str     r1,[r0,#SD_IE]
   
    // send init commands 
    //TODO: should set "block mode" in the OCR using CMD1
    ldr     r0,=MMC_CMD1  // set Operating Condition Register
    bl      sendCommand

//    ldr     r3,=0x40000000
//    ldr     r4,=0x80000000
//1:  mov     r1,r0
//    orr     r1,r3
//    ldr     r0,=MMC_CMD1  // set Operating Condition Register
//    bl      sendCommand
//    tst     r0,r4
//    bne     1b
    

    //TODO: should set 8bit transfer

//    ldr     r0,=MMC_CMD6
//    ldr     r1,=0x03B70200      // 8bit bus width. from JEDEC Standard No. 84-b50.1 page 263
//    bl      sendCommand
//    ldr     r0,=MMC1
//    ldr     r1,=(1<<5) 
//    str     r1,[r0,#SD_CON]

    pop(r0-r4,r15)

// r0=cmd with flags
// r1=args
//RETURN: r0,r1,r2,r3: response
sendCommand:
    push(r5-r9,r14)

    ldr     r7,=0x10000         // error detection mask for checking SD_STAT
    ldr     r5,=MMC1
    mvn     r6,#1
    str     r6,[r5,#SD_STAT]    // clear status
    str     r1,[r5,#SD_ARG]
    str     r0,[r5,#SD_CMD]
    // read stat reg until Command Complete or Error
1:  ldr     r6,[r5,#SD_STAT]
    tst     r6,#1    // Command Complete?
    bne     2f
    tst     r6,r7   //Error?
    beq     1b
    pop(r5-r9,r15)  // exit on error (such as timeout)
2:  ldr     r0,[r5,#SD_RSP10]           // success oath, read response and return
    ldr     r1,[r5,#SD_RSP32]
    ldr     r2,[r5,#SD_RSP54]
    ldr     r3,[r5,#SD_RSP76]
    pop(r5-r9,r15)

//TODO: I dont know why I need to use byte addressing. I would rather do block addressing. 
//  I will probably have to read more about the SD protocol to get that working
// r5: buffer to transfer data to.
// r6: address
emmc_read_sector:
    push(r0-r5,r14)

    lsl     r6,#9 // This is temporary because I cant put the device in block mode

    ldr     r4,=MMC1
    ldr     r1,=512|(1<<16)
    str     r1,[r4,#SD_BLK]
    ldr     r0,=MMC_CMD17
    mov     r1,r6
    bl      sendCommand

1:  ldr     r1,[r4,#SD_STAT]
    tst     r1,#(1<<5)           // check if buffer read ready
    beq     1b

    //Copy to buffer
    mov     r3,#(512/4)
1:  ldr     r1,[r4,#SD_DATA]
    str     r1,[r5],#4
    subs    r3,#1
    bne     1b
    pop(r0-r5,r15)




