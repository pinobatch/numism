#!/bin/sh
set -e

rgbgfx -d 1 -o obj/gb/Crash_dump_uncial.1b tilesets/Crash_dump_uncial.png

rgbasm -o obj/gb/header.o src/header.z80
rgbasm -o obj/gb/init.o src/init.z80
rgbasm -o obj/gb/main.o src/main.z80
rgbasm -o obj/gb/pads.o src/pads.z80
rgbasm -o obj/gb/ppuclear.o src/ppuclear.z80

rgblink -o exercise.gb -p 0xFF obj/gb/header.o obj/gb/init.o obj/gb/main.o obj/gb/pads.o obj/gb/ppuclear.o
rgbfix -jvt 'EXERCISE' -p 0xFF exercise.gb

