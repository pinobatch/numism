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
Stage 1 (No$nes) is in progress.  Afterward comes NESticle time.

1. Reading $20E0,X with X=$22 does dummy read from $2002 (PPU status)
   then reads $2102 bit 7 false
2. Writing $00 to $4017 (APU length counter) sets bit 6 of $4015
   (APU status) 1/60 second later
3. Note on pulse 1 sets $4015 bit 0; length counter expiry clears it
4. Branching from $BFFx in bank 0 to $C00x in the fixed bank works
   (mapper dependent)
5. Sprite at Y=$FF (vertically off screen) doesn't trigger sprite 0
   hit
6. Sprite 0 hit triggers in all four flip states
7. Having nine or more sprites on a scanline turns on the overflow
   flag ($2002 bit 5), provided rendering is on for that line
8. 
9. 
10. 
11. Second $2002 read in vblank has bit 7 false
12. 
13. 
14. Branching between $FFxx and $00xx wraps correctly  
    (Because of NESticle, No$nes, and PocketNES behaviors that can
    crash the test, this checks whether coins 4 and 11 passed first.)
15. 
16. 
17. 
18. 
19. 
20. 

### Unsorted

* Playing a short sample should have $4015 D4 go 1 then 0
* Sprite 0 when X=$00 and left 8 pixels are disabled
* 9 sprites high on screen, disable rendering during those, 9 more
  sprites low on screen
* DPCM causing $2007 double reads should be stage 3+ because it's
  an NTSC/PAL difference
