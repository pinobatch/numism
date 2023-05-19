#!/bin/sh
set -e
rgbgfx -c embedded -o level1chr.2b level1chr.png
rgbasm -hL -p 0xFF -o level1.o level1.asm
rgblink -dt -p 0xFF -o level1.gb -n level1.sym level1.o
rgbfix -jv -p 0xFF level1.gb
