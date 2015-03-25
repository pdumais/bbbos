#define L1_TYPE_SECTION     0b10
#define L1_TYPE_PAGETABLE   0b01
#define L1_TYPE_SMALLPAGE   0b10
#define DOMAIN_BIT_INDEX    5
#define SECTION_CB              0b1100
#define PAGE_CB                 0b1100
#define PAGE_NG             0b100000000000


// It seems that we are using the old descriptor format. I'm not sure why
#define PAGE_AP_NONO 0b0000000000
#define PAGE_AP_RWNO 0b0000010000
#define PAGE_AP_RWRO 0b0000100000
#define PAGE_AP_RWRW 0b0000110000

#define SECTION_AP_NONO 0b000000000000
#define SECTION_AP_RWNO 0b010000000000
#define SECTION_AP_RWRO 0b100000000000
#define SECTION_AP_RWRW 0b110000000000

#define PAGE_EXECUTE_NEVER      0b1
#define SECTION_EXECUTE_NEVER   0b10000

