#!/bin/sh
#
# who needs gnu make for something this simple?
#
# Copyright 2020 Damian Yerrick
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
set -e

title=numism
inttitle='NUMISM'
objlist='header init ppuclear pads main unpb16 uniur coins continue vwflabels vwfdraw'
genobjlist='vwf7_cp144p'
twobitlist='coincels'
pb16list='checkmark'
iurlist='logo'

mkdir -p obj/gb
echo 'Force folder creation' > obj/gb/index.txt

python3 tools/vwfbuild.py tilesets/vwf7_cp144p.png obj/gb/vwf7_cp144p.z80
for filename in $twobitlist $pb16list; do
  rgbgfx -o "obj/gb/$filename.2b" "tilesets/$filename.png"
done
for filename in $pb16list; do
  python3 tools/pb16.py "obj/gb/$filename.2b" "obj/gb/$filename.2b.pb16"
done
for filename in $iurlist; do
  rgbgfx -o "obj/gb/$filename.2b" "tilesets/$filename.png"
  python3 tools/incruniq.py "obj/gb/$filename.2b" "obj/gb/$filename.iur"
done
for filename in $objlist; do
  # need -h to make double-inc halts
  rgbasm -o "obj/gb/$filename.o" -h "src/$filename.z80"
done
for filename in $genobjlist; do
  # need -h to make double-inc halts
  rgbasm -o "obj/gb/$filename.o" -h "obj/gb/$filename.z80"
done
objlisto=$(printf "obj/gb/%s.o " $objlist $genobjlist)
rgblink -o "$title.gb" -p 0xFF -m "$title.map" -n "$title.sym" $objlisto
rgbfix -jvt "$inttitle" -l0x33 -m0 -n0 -p0xFF -r0 "$title.gb"

