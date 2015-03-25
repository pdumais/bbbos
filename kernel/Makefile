SOURCES=init.S debug.S interupts.S mmu.S process.S swi.S failures.S am335xTimer.S prcm.S emmc.S gpio.S uart.S spi.S 25aa256.S mcp23s18.S
TARGET=kernel
BINDIR=../bin/
AS=arm-unknown-linux-gnueabi-gcc
LD=arm-unknown-linux-gnueabi-ld
CC=arm-unknown-linux-gnueabi-cc
OBJDUMP=arm-unknown-linux-gnueabi-objdump
OBJCOPY=arm-unknown-linux-gnueabi-objcopy
OBJECTS=$(SOURCES:%.S=$(BINDIR)%.o)

all: $(TARGET).bin

$(OBJECTS): $(BINDIR)%.o : ./%.S *.h ../board.h
	mkdir -p $(BINDIR)
	$(AS) -mcpu=cortex-a8 -ffreestanding -c $< -o $@


kernel.bin: $(OBJECTS)
	$(LD) -T link.ld $(OBJECTS) -o $(BINDIR)$(TARGET).elf
	$(OBJCOPY) $(BINDIR)$(TARGET).elf -O binary $(BINDIR)$(TARGET).bin

