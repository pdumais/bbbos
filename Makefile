MAXBINSIZE=83886080  
BINDIR=bin/
TFTPDIR=/var/tftp/
APPS=test1 test2
AS=arm-unknown-linux-gnueabi-gcc
LD=arm-unknown-linux-gnueabi-ld
CC=arm-unknown-linux-gnueabi-cc
OBJDUMP=arm-unknown-linux-gnueabi-objdump
OBJCOPY=arm-unknown-linux-gnueabi-objcopy
OBJECTS=$(SOURCES:%.S=$(BINDIR)%.o)
BINS=$(APPS:%=%.bin)
APPSIMAGES=$(APPS:%=$(BINDIR)%.bin)

all: linkerscript kernel $(BINS)
	cp $(BINDIR)kernel.bin $(BINDIR)os.bin
	truncate -s 512 $(BINDIR)appstoc.bin
	cat $(BINDIR)appstoc.bin > $(BINDIR)apps.bin
	cat $(BINDIR)allapps.bin >> $(BINDIR)apps.bin
	test -n "$$(find $(BINDIR)os.bin -size -$(MAXBINSIZE))c" || rm $(BINDIR)os.bin
	test -e $(BINDIR)os.bin
	cp $(BINDIR)*.bin $(TFTPDIR)
	chmod 777 $(TFTPDIR)*.bin


.PHONY: resetapps
resetapps:
	-@rm $(BINDIR)appstoc.bin
	-@rm $(BINDIR)allapps.bin
	mkdir -p apps/bin

$(BINS): %.bin : ./apps/% resetapps
	cd $< && make
	perl -e "print pack('L',`stat -c %s ./apps/bin/$@`)" >> $(BINDIR)appstoc.bin
	cat ./apps/bin/$@ >> $(BINDIR)allapps.bin

.PHONY: kernel
kernel:
	cd kernel && make

linkerscript: board.h
	cpp -P kernel/link.ld.in -o kernel/link.ld
	cpp -P apps/link.ld.in -o apps/link.ld


.PHONY: clean
clean:
	-@rm -f $(BINDIR)*.o
	-@rm -f $(BINDIR)*.bin
	-@rm -f $(BINDIR)*.elf

