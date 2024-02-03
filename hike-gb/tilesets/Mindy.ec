# Mindy Beageonton, third grader and coin collector

# 0 is skin+shirt; 1 is skirt+hair
# for DMG X-priority rule, ensure each color appears once and only
# once in the palette lines
# A00 is shoes to appear as dark skin on 3bpp platforms (SMS, SNES)
# or as green on 2bpp layered platforms (like NES, DMG, and GBC)
backdrop #AAF
palette 0x06 #FFF #FAA #A55
palette 0x17 #af0 #55a #005 #5A0=3 #A00=1

frame Mindy_stand
  strip 0x06  86  43  8 16
  strip 0x17  80  40 16 24

frame Mindy_turn
  strip 0x06 104  42 16 16
  strip 0x17 108  40  8 16
  strip 0x17 104  56 16  8

frame Mindy_stop1
  strip 0x06  14  43  8 16
  strip 0x17   8  40 16 24

frame Mindy_stop2
  strip 0x06  38 43  8 16
  strip 0x17  32 40 16 16
  strip 0x17  34 56 16  8
  hotspot 40 64

frame Mindy_stop_last repeats Mindy_stop1

frame Mindy_start1
  strip 0x06  14  76  8  8
  strip 0x06   8  84 16  5
  strip 0x17   8  73 16 16
  strip 0x17   7  89 16  7
  hotspot 16 96

frame Mindy_start2
  strip 0x06  30  75  8 16
  strip 0x17  24  72 16 24

frame Mindy_walk1
  strip 0x06  54  76  8  8
  strip 0x06  48  84 16  8
  strip 0x17  48  73 16 23

frame Mindy_walk2 repeats Mindy_walk1

frame Mindy_walk3
  strip 0x06  70  75 8 16
  strip 0x17  64  72 16 24

frame Mindy_walk4 repeats Mindy_walk3

frame Mindy_walk5
  strip 0x06  86  76  8  8
  strip 0x06  80  84 16  5
  strip 0x17  80  73 16 23

frame Mindy_walk6 repeats Mindy_walk5

frame Mindy_walk7
  strip 0x06 102  75  8 16
  strip 0x17  96  72 16 24

frame Mindy_walk8 repeats Mindy_walk7

frame Mindy_crouch1
  strip 0x06  14 108  8 16
  strip 0x17   8 104 16 24

frame Mindy_crouch2
  strip 0x06  30 109  8 16
  strip 0x17  24 106 16 22

frame Mindy_crouch3
  strip 0x06  46 112  8 16
  strip 0x17  40 109 16 19

frame Mindy_crouch4 56 112 16 16
  strip 0x06  62 115  8 13
  strip 0x17

frame Mindy_crouch_last 72 112 16 16
  strip 0x06  78 115  8 13
  strip 0x17

frame Mindy_crouch_lean1 96 112 16 16
  strip 0x06 102 115  8 13
  strip 0x17
  hotspot 103 128

frame Mindy_crouch_lean2 112 112 16 16
  strip 0x06 120 116  8 12
  strip 0x17 114 112 14  8
  strip 0x17 112 120 16 16
  hotspot 119 128

frame Mindy_crouch_lean 128 112 16 16
  strip 0x06 136 116  8 12
  strip 0x17 130 112 14  8
  strip 0x17 128 120 16  8
  hotspot 135 128

frame Mindy_crouch_leanout1 144 112 16 16
  strip 0x06 150 115  8 13
  strip 0x17
  hotspot 151 128

frame Mindy_crouch_leanout_last 160 112 14 16
  strip 0x06 165 115  8 13
  strip 0x17 158 112 16 16
  hotspot 167 128

frame Mindy_uncrouch_1 184 112 16 16
  strip 0x06 189 114  8 14
  strip 0x17

frame Mindy_uncrouch_2 200 110 16 18
  strip 0x06 206 113  8 13
  strip 0x17

frame Mindy_uncrouch_3 216 107 16 21
  strip 0x06 222 110  8 16
  strip 0x17

frame Mindy_uncrouch_last 232 104 16 24
  strip 0x06 238 107  8 16
  strip 0x17

frame Mindy_hoist_leap_1 8 152 16 24
  strip 0x06  14 154  8 12
  strip 0x06  21 160  3  4
  strip 0x17 8 152 14 24

frame Mindy_hoist_leap_2 24 154 16 22
  strip 0x06  30 157  8 12
  strip 0x06  37 160  3  4
  strip 0x17 24 154 14 22

frame Mindy_hoist_leap_3 40 156 16 20
  strip 0x06  46 160 10  8
  strip 0x06  46 168  8  8
  strip 0x17 40 157 14 19

frame Mindy_hoist_leap_4 56 155 16 21
  strip 0x06  61 158 16  8
  strip 0x06  62 166  8  8
  strip 0x17  56 155 14 16
  strip 0x17  55 171 15  5

# Hold on this frame until at the right height
frame Mindy_hoist_leap_last 72 152 16 24
  strip 0x06  78 154  8 12
  strip 0x06  85 160  3  4
  strip 0x17  72 152 14 24

# Before climb_1 through climb_4, move 4 pixels up each
# Before climb_4 through climb_last, move 4 pixels forward each
frame Mindy_hoist_climb_1 88 148 16 24
  strip 0x06  94 150  8  8
  strip 0x06  94 158 10  8
  strip 0x17

frame Mindy_hoist_climb_2 104 144 16 24
  strip 0x06 110 146  8 16
  strip 0x06 118 158  2  4
  strip 0x17

frame Mindy_hoist_climb_3 120 140 17 24
  strip 0x06 127 142  8 16
  strip 0x06 128 158  8  8
  strip 0x17 120 140 16 16
  strip 0x17 121 156 16  8
  hotspot 128 164

frame Mindy_hoist_climb_4
  strip 0x06 149 143  8 15
  strip 0x06 118 158  2  4 at 151 156
  strip 0x17 142 140 16 20
  hotspot 148 160

frame Mindy_hoist_climb_5
  strip 0x06 169 143  8  8
  strip 0x06 167 151  6  7
  strip 0x06 118 158  2  4 at 167 156
  strip 0x17 162 140 16 20
  hotspot 168 160

frame Mindy_hoist_climb_6
  strip 0x06 189 143  8  8
  strip 0x06 187 151  6  7
  strip 0x17 183 140 16 20
  hotspot 188 160

frame Mindy_hoist_climb_last
  strip 0x06 206 143  8 16
  strip 0x17 200 140 16 20
  hotspot 208 160
# next frame is Mindy_uncrouch_3

