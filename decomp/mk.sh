#!/bin/sh
set -e
mkdir -p obj/gb
python3 tools/rectallocate.py -o obj/gb/level1.shelves.asm src/level1.shelves
rgbasm -hL -p 0xFF -o obj/gb/level1.shelves.o obj/gb/level1.shelves.asm
python3 tools/vwfbuild.py tilesets/Fauxtura.png obj/gb/Fauxtura.asm
rgbasm -hL -p 0xFF -o obj/gb/Fauxtura.o obj/gb/Fauxtura.asm
python3 tools/extractcels.py --streaming tilesets/Mindy.ec tilesets/Mindy.png obj/gb/Mindy.2b obj/gb/Mindy.asm
rgbgfx -c embedded -o obj/gb/level1chr.2b tilesets/level1chr.png
rgbgfx -c embedded -o obj/gb/coincels.2b tilesets/coincels.png
rgbgfx -c embedded -o obj/gb/cursor.2b tilesets/cursor.png
rgbgfx -c embedded -o obj/gb/title.2b -b0x80 -ut obj/gb/title.nam tilesets/title.png
rgbasm -hL -p 0xFF -o obj/gb/level1.o src/level1.asm
rgbasm -hL -p 0xFF -o obj/gb/pads.o src/pads.asm
rgbasm -hL -p 0xFF -o obj/gb/vwfdraw.o src/vwfdraw.asm
python3 tools/savescan.py -o obj/gb/localvars.asm src/*.asm
rgbasm -hL -p 0xFF -o obj/gb/localvars.o obj/gb/localvars.asm
rgblink -dt -p 0xFF -o Mindy_GMQ7.gb -n Mindy_GMQ7.sym \
  obj/gb/level1.o obj/gb/pads.o obj/gb/vwfdraw.o obj/gb/localvars.o \
  obj/gb/Fauxtura.o obj/gb/level1.shelves.o
rgbfix -jv -p 0xFF -t "MINDY GMQ7" Mindy_GMQ7.gb
