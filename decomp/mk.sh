#!/bin/sh
set -e
mkdir -p obj/gb
python3 tools/rectallocate.py -o obj/gb/level1.shelves.asm src/level1.shelves
rgbasm -hL -p 0xFF -o obj/gb/level1.shelves.o obj/gb/level1.shelves.asm
rgbgfx -c embedded -o obj/gb/level1chr.2b tilesets/level1chr.png
rgbgfx -c embedded -o obj/gb/coincels.2b tilesets/coincels.png
rgbgfx -c embedded -o obj/gb/cursor.2b tilesets/cursor.png
rgbasm -hL -p 0xFF -o obj/gb/level1.o src/level1.asm
rgbasm -hL -p 0xFF -o obj/gb/pads.o src/pads.asm
rgblink -dt -p 0xFF -o level1.gb -n level1.sym \
  obj/gb/level1.o obj/gb/pads.o obj/gb/level1.shelves.o
rgbfix -jv -p 0xFF -t "HIDDEN COINS" level1.gb
