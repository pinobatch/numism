# Mindy Beageonton, third grader and coin collector

# 0 is skin+shirt; 1 is skirt+hair
backdrop #AAF
palette 0 #FFF #FAA #A55
palette 0x11 #af0 #55a #005 #A55=1 #5A0=2 #FFF=1

frame Mindy_stand
  strip 0     86  43  8 16
  strip 0x11  80  40 16 24

frame Mindy_turn
  strip 0    104  42 16 16
  strip 0x11 108  40  8 16
  strip 0x11 104  56 16  8

frame Mindy_stop1
  strip 0     14  43  8 16
  strip 0x11   8  40 16 24

frame Mindy_stop2
  strip 0     38 43  8 16
  strip 0x11  32 40 16 16
  strip 0x11  34 56 16  8
  hotspot 40 64

frame Mindy_stop_last repeats Mindy_stop1

frame Mindy_start1
  strip 0     14  76  8  8
  strip 0      8  84 16  8
  strip 0x11   8  73 16 16
  strip 0x11   7  89 16  7
  hotspot 16 96

frame Mindy_start2
  strip 0     30  75  8 16
  strip 0x11  24  72 16 24

frame Mindy_walk1
  strip 0     54  76  8  8
  strip 0     48  84 16  8
  strip 0x11  48  73 16 23

frame Mindy_walk2 repeats Mindy_walk1

frame Mindy_walk3
  strip 0     70  75 8 16
  strip 0x11  64  72 16 24

frame Mindy_walk4 repeats Mindy_walk3

frame Mindy_walk5
  strip 0     86  76  8  8
  strip 0     80  84 16  8
  strip 0x11  80  73 16 23

frame Mindy_walk6 repeats Mindy_walk5

frame Mindy_walk7
  strip 0    102  75  8 16
  strip 0x11  96  72 16 24

frame Mindy_walk8 repeats Mindy_walk7

frame Mindy_crouch1
  strip 0     14 108  8 16
  strip 0x11   8 104 16 24

frame Mindy_crouch2
  strip 0     30 109  8 16
  strip 0x11  24 106 16 22

frame Mindy_crouch3
  strip 0     46 112  8 16
  strip 0x11  40 109 16 19

frame Mindy_crouch4 56 112 16 16
  strip 0     62 115  8 13
  strip 0x11

frame Mindy_crouch_last 72 112 16 16
  strip 0     78 115  8 13
  strip 0x11

frame Mindy_crouch_lean1 96 112 16 16
  strip 0    102 115  8 13
  strip 0x11
  hotspot 103 128

frame Mindy_crouch_lean2 112 112 16 16
  strip 0    120 116  8 12
  strip 0x11
  hotspot 119 128

frame Mindy_crouch_lean 128 112 16 16
  strip 0    136 116  8 12
  strip 0x11
  hotspot 135 128

frame Mindy_crouch_leanout1 144 112 16 16
  strip 0    150 115  8 13
  strip 0x11
  hotspot 151 128

frame Mindy_crouch_leanout_last 160 112 14 16
  strip 0    165 115  8 13
  strip 0x11 158 112 16 16
  hotspot 167 128

frame Mindy_uncrouch_1 184 112 16 16
  strip 0    189 114  8 14
  strip 0x11

frame Mindy_uncrouch_2 200 110 16 18
  strip 0    206 113  8 13
  strip 0x11

frame Mindy_uncrouch_3 216 107 16 21
  strip 0    222 110  8 16
  strip 0x11

frame Mindy_uncrouch_last 232 104 16 24
  strip 0    238 107  8 16
  strip 0x11

frame Mindy_hoist_leap_1 8 152 16 24
  strip 0     14 154  8 12
  strip 0     21 160  3  4
  strip 0x11

frame Mindy_hoist_leap_2 24 153 16 23
  strip 0     30 156  8 12
  strip 0     37 160  3  4
  strip 0x11

frame Mindy_hoist_leap_3 40 156 16 20
  strip 0     46 159 10  8
  strip 0     46 167  8  8
  strip 0x11

frame Mindy_hoist_leap_4 56 155 16 21
  strip 0     61 158 16  8
  strip 0     61 166  8  8
  strip 0x11

# Hold on this frame until at the right height
frame Mindy_hoist_leap_last 72 152 16 24
  strip 0     78 154  8 12
  strip 0     85 160  3  4
  strip 0x11

# Before climb_1 through climb_4, move 4 pixels up each
# Before climb_4 through climb_last, move 4 pixels forward each
frame Mindy_hoist_climb_1 88 148 16 24
  strip 0     94 150  8  8
  strip 0     94 158 10  8
  strip 0x11

frame Mindy_hoist_climb_2 104 144 16 24
  strip 0    110 146  8 16
  strip 0    118 158  2  4
  strip 0x11

frame Mindy_hoist_climb_3 120 140 17 24
  strip 0    127 142  8 16
  strip 0    128 158  8  8
  strip 0x11 120 140 16 16
  strip 0x11 121 156 16  8
  hotspot 128 164

frame Mindy_hoist_climb_4
  strip 0    149 143  8 15
  strip 0    118 158  2  4 at 151 156
  strip 0x11 142 140 16 20
  hotspot 148 160

frame Mindy_hoist_climb_5
  strip 0    169 143  8  8
  strip 0    167 151  6  7
  strip 0    118 158  2  4 at 167 156
  strip 0x11 162 140 16 20
  hotspot 168 160

frame Mindy_hoist_climb_6
  strip 0    189 143  8  8
  strip 0    187 151  6  7
  strip 0x11 183 140 16 20
  hotspot 188 160

frame Mindy_hoist_climb_last
  strip 0    206 143  8 16
  strip 0x11 200 140 16 20
  hotspot 208 160
# next frame is Mindy_uncrouch_3

