#!/bin/sh
set -e

mkdir -p obj/gb
echo 'Force folder creation' > obj/gb/index.txt

rgbgfx -o obj/gb/logo.2b tilesets/logo.png
python3 tools/incruniq.py obj/gb/logo.2b obj/gb/logo.iur

rgbasm -o obj/gb/header.o src/header.z80
rgbasm -o obj/gb/init.o src/init.z80
rgbasm -o obj/gb/ppuclear.o src/ppuclear.z80
rgbasm -o obj/gb/pads.o src/pads.z80
rgbasm -o obj/gb/main.o src/main.z80
rgbasm -o obj/gb/unpb16.o src/unpb16.z80
rgbasm -o obj/gb/uniur.o src/uniur.z80

rgblink -m numism.map -n numism.sym -o numism.gb -dtp 0xFF \
  obj/gb/header.o obj/gb/init.o obj/gb/ppuclear.o obj/gb/pads.o \
  obj/gb/main.o obj/gb/unpb16.o obj/gb/uniur.o

# Not yet SGB or GBC aware
rgbfix -jv -kP8 -l0x33 -m0 -n0 -p0xFF -r0 -t"NUMISM" numism.gb
