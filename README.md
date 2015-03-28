# bbbos
A BeagleBoneBlack operating system written in assembly.

The kernel provides a 32bit virtual memory manager and a full preemptive task scheduler. 

The bbbreset.sh script can be ignored. It is a script that I use to toggle a relay on a WebRelay device. The relay
power-sycles my BBB. It makes things easier because I don't have to manually reset the BBB each time.

This software was working with a mcp23s18 port expander chip, a 25aa256 eeprom and uart1 on max232

BeagleBoneBlack
SoC: AM3359
    CPU: Cortex-a8 (armv7 architecture)
    PIC:
    Timer
    Ethernet

The kernel image will be copied to 0x80000000 by uboot and execution will start from there
Booting will try to download a kernel image from tftp. This is mandatory
```
Pins
    p9.2: gnd
    p9.4: 3.3
    p9.6: 5
    p9.12: gpio60: int pin of mcp23s18
    p9.24: uart1 tx
    p9.26: uart1 rx
    p9.28: spi1 chip select 0 (mcp23s18)
    p9.29: spi1 MOSI
    p9.30: spi1 MISO
    p9.31: spi1 CLK
    p9.42: spi1 chip select 1 (eeprom)

    p8.2: gnd
    p8.7: GPIO66 (switch)
```
