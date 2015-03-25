SOURCES=main.S
BINDIR=../bin/
TARGET=$(notdir $(shell pwd))
AS=arm-unknown-linux-gnueabi-gcc
LD=arm-unknown-linux-gnueabi-ld
CC=arm-unknown-linux-gnueabi-cc
OBJDUMP=arm-unknown-linux-gnueabi-objdump
OBJCOPY=arm-unknown-linux-gnueabi-objcopy
OBJECTS=$(SOURCES:%.S=%.o)

all: $(TARGET).bin

$(OBJECTS): %.o : %.S
	mkdir -p $(BINDIR)
	$(AS) -ffreestanding -c $< -o $@


$(TARGET).bin: $(OBJECTS)
	$(LD) -T ../link.ld $(OBJECTS) -o $(BINDIR)$(TARGET).elf
	$(OBJCOPY) $(BINDIR)$(TARGET).elf -O binary $(BINDIR)$(TARGET).bin

