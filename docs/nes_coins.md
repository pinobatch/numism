NES coin ideas
==============

Many free or freeware console emulators fail accuracy test ROMs due
to behavior differences from authentic hardware.  I plan to research
the precise behaviors underlying test failures and then produce
"coins", or minimal test routines to highlight these differences.

See [What makes a good coin?] for what I'm aiming at and
[NES emulator testing] for my thought processes.

I estimate that the uncompressed descriptions of each stage's
coins total 800 bytes.  All stages could add up to several
kilobytes of ROM.  I may have to use the DTE codec that I used for
[240p Test Suite].

[What makes a good coin?]: ./good_coin.md
[NES emulator testing]: ./nes_emu_testing.md
[240p Test Suite]: https://github.com/pinobatch/240p-test-mini/nes

Coin list
---------
A preliminary list for stages 1 and 2 is complete.

1. Reading $20E0,X with X=$22 does dummy read from $2002 (PPU status)
   then reads $2102 bit 7 false
2. Writing $00 to $4017 (APU length counter) sets bit 6 of $4015
   (APU status) 1/60 second later
3. 
4. Branching between $FFxx and $00xx wraps correctly
5. Sprite at Y=$FF (vertically off screen) doesn't trigger sprite 0
   hit
6. 
7. 
8. 
9. 
10. 
11. 
12. 
13. 
14. 
15. 
16. 
17. 
18. 
19. 
20. 

### Unsorted

* Branch wrapping across $0000 and $FFFF
* Playing a short note on pulse 1 should have $4015 D0 go 1 then 0
* Playing a short sample should have $4015 D4 go 1 then 0
* Sprite 0 when Y=$FF
* Sprite 0 when X=$00 and left 8 pixels are disabled
* 9 sprites high on screen, disable rendering during those, 9 more
  sprites low on screen
* Timing of when $2002 bits get cleared
* DPCM causing $2007 double reads should be stage 3+ because it's
  an NTSC/PAL difference
