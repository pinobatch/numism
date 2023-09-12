#!/bin/sh
set -e

title=Mindy_GMQ7
inttitle='MINDYS HIKE'
objlist='level1 pads vwfdraw unpb16'
genobjlist='Fauxtura level1.shelves localvars'
twobitlist=''
pb16list='level1chr coincels cursor'

mkdir -p obj/gb

# convert special images
python3 tools/vwfbuild.py tilesets/Fauxtura.png obj/gb/Fauxtura.asm
python3 tools/extractcels.py --streaming tilesets/Mindy.ec tilesets/Mindy.png obj/gb/Mindy.2b obj/gb/Mindy.asm

# convert ordinary images
rgbgfx -c embedded -o obj/gb/title.2b -b0x80 -ut obj/gb/title.nam tilesets/title.png
for filename in $twobitlist $pb16list; do
  rgbgfx -c embedded -o "obj/gb/$filename.2b" "tilesets/$filename.png"
done
for filename in $pb16list; do
  python3 tools/pb16.py "obj/gb/$filename.2b" "obj/gb/$filename.2b.pb16"
done

# allocate variables
python3 tools/rectallocate.py -o obj/gb/level1.shelves.asm src/level1.shelves
python3 tools/savescan.py -o obj/gb/localvars.asm src/*.asm

# assemble
for filename in $objlist; do
  rgbasm -hL -p 0xFF -o "obj/gb/$filename.o" "src/$filename.asm"
done
for filename in $genobjlist; do
  rgbasm -hL -p 0xFF -o "obj/gb/$filename.o" "obj/gb/$filename.asm"
done

# make executable
objlisto=$(printf "obj/gb/%s.o " $objlist $genobjlist)
rgblink -dt -p 0xFF -o "$title.gb" -n "$title.sym" $objlisto
rgbfix -jv -t "$inttitle" -p 0xFF "$title.gb"
