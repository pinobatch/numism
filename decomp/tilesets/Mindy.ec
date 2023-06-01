# Mindy Beageonton, third grader and coin collector

# 0 is skin+shirt; 1 is skirt+hair
backdrop #AAF
palette 0 #FFF #FAA #A55
palette 0x11 #af0 #55a #005 #A55=1 #5A0=2

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
  strip 0 14 108 8 16
  strip 0x11 8 104 16 24

frame Mindy_crouch2
  strip 0 30 109 8 16
  strip 0x11 24 106 16 22

frame Mindy_crouch3
  strip 0 46 112 8 16
  strip 0x11 40 109 16 19

frame Mindy_crouch4 56 112 16 16
  strip 0 62 115 8 13
  strip 0x11

frame Mindy_crouch_last 72 112 16 16
#  strip 0 78 115 8 13
#  strip 0x11
