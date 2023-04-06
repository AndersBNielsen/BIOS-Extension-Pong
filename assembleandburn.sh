#!/bin/bash
nasm helloworld.asm
./floppy_bios/fix_checksum helloworld helloworld 0 3fff 3fff
cat 48k.bin helloworld > 64krom.bin
minipro -p "W27C512@DIP28" -w 64krom.bin
