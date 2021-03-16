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
Stage 1 (No$nes) is complete.  Stage 2 starts targeting other
emulators, particularly NESticle.

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
7. DMC sample sets $4015 bit 4; end of sample clears it
8. Indexed write to $2007 advances the VRAM pointer before writing
9. Having nine or more sprites on a scanline turns on the overflow
   flag ($2002 bit 5), provided rendering is on for that line
10. $2002 bit 7 can read true and suppress NMI
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

### Delayed

Stage 1 has four $2002 tests, three $4015 tests, one $2007 test,
and one CPU-to-mapper interaction test.  To ensure variety, prefer
pushing these to a later stage:

- Sprite overflow coarse timing 0-8 vs. 54-62
- Sprite overflow doesn't depend on X=0 vs. X=255
- Sprite overflow Y=239, but not Y=240 or Y=255
- Sprite 0 coarse timing X=0 vs. X=254
- Sprite 0 when X=$00 and left 8 pixels are disabled
- Anything relying on PSG channels' length counter

Not for stage 1 because games rarely rely on timing margins this
tight:

- `ppu_vbl_nmi`
- OAM DMA and DMC DMA interaction

Not for stage 1 because No$nes gets it right:

- `io_db`/`PPUGenLatch` decay behavior

Saving for stage 3 over NTSC/PAL difference, which I deem analogous
to GB/GBC difference:

- DMC DMA causing $2007 double reads

### Unsorted

* INC $2007,X
