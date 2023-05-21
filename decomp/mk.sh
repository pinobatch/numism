#!/bin/sh
set -e
mkdir -p obj/gb
python3 tools/rectallocate.py -o obj/gb/level1.shelves.asm src/level1.shelves
rgbasm -hL -p 0xFF -o obj/gb/level1.shelves.o obj/gb/level1.shelves.asm
rgbgfx -c embedded -o obj/gb/level1chr.2b tilesets/level1chr.png
rgbasm -hL -p 0xFF -o obj/gb/level1.o src/level1.asm
rgblink -dt -p 0xFF -o level1.gb -n level1.sym \
  obj/gb/level1.o obj/gb/level1.shelves.o
rgbfix -jv -p 0xFF level1.gb
