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
objlist='header init ppuclear pads main unpb16 uniur coins gbccoins sgbcoins continue sramlog vwflabels vwfdraw sgb sgbborder'
genobjlist='vwf7_cp144p'
twobitlist='coincels'
pb16list='checkmark'
iurlist='logo'
oaat_objlist='header init ppuclear pads oneatatime coins gbccoins sgbcoins sgb'

allobjlist=$(printf '%s\n' $objlist $oaat_objlist | sort -u)

mkdir -p obj/gb
echo 'Force folder creation' > obj/gb/index.txt

python3 tools/vwfbuild.py tilesets/vwf7_cp144p.png obj/gb/vwf7_cp144p.z80
python3 tools/borderconv.py tilesets/Elembis_border.png obj/gb/Elembis.border
for filename in $twobitlist $pb16list; do
  rgbgfx -c embedded -o "obj/gb/$filename.2b" "tilesets/$filename.png"
done
for filename in $pb16list; do
  python3 tools/pb16.py "obj/gb/$filename.2b" "obj/gb/$filename.2b.pb16"
done
for filename in $iurlist; do
  rgbgfx -c embedded -o "obj/gb/$filename.2b" "tilesets/$filename.png"
  python3 tools/incruniq.py "obj/gb/$filename.2b" "obj/gb/$filename.iur"
done
for filename in $allobjlist; do
  rgbasm -o "obj/gb/$filename.o" "src/$filename.z80"
done
for filename in $genobjlist; do
  rgbasm -o "obj/gb/$filename.o" "obj/gb/$filename.z80"
done
objlisto=$(printf "obj/gb/%s.o " $objlist $genobjlist)
rgblink -o "$title.gb" -d -p 0xFF -m "$title.map" -n "$title.sym" $objlisto
oaat_objlisto=$(printf "obj/gb/%s.o " $oaat_objlist $genobjlist)
rgblink -o "$title-oneatatime.gb" -d -p 0xFF -m "$title-oneatatime.map" -n "$title-oneatatime.sym" $oaat_objlisto

# per beware: don't add -s until SGB-related tests are ready
cp "$title.gb" "$title-sram.gb"
cp "$title.sym" "$title-sram.sym"
rgbfix -jvt "$inttitle" -l0x33 -m0 -n0 -p0xFF -r0 -sc "$title.gb"
rgbfix -jvt "$inttitle 1AAT" -l0x33 -m0 -n0 -p0xFF -r0 -sc "$title-oneatatime.gb"
rgbfix -jvt "$inttitle" -l0x33 '-mMBC5+RAM+BATTERY' -n0 -p0xFF -r2 -sc "$title-sram.gb"
