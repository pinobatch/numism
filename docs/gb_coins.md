Game Boy coin ideas
===================

Many free or freeware console emulators fail accuracy test ROMs due
to behavior differences from authentic hardware.  I plan to research
the precise behaviors underlying test failures and then produce
"coins", or minimal test routines to highlight these differences.

See [What makes a good coin?] for what I'm aiming at and
[Game Boy emulator testing] for my thought processes.

I estimate that the uncompressed descriptions of each stage's
coins total 800 bytes.  All ten stages could add up to a quarter
of a 32K ROM.  I may have to use the DTE codec that I used for
[144p Test Suite].

[What makes a good coin?]: ./good_coin.md
[Game Boy emulator testing]: ./gb_emu_testing.md
[144p Test Suite]: https://github.com/pinobatch/240p-test-mini/gameboy

Coin list
---------
A preliminary list for stages 1 and 2 is complete.

1. `add hl` flags
2. `add sp` flags
3. APU writes while off not honored, before or after turning back on
4. Filling APU with zeroes causes OR mask to be read back
5. Upward sweep turns off NR52 status and downward sweep doesn't
6. APU length counter expiry and envelope $00 turn off NR52 status
7. DIV increases by 1 unit per period
8. Can get LYC and mode 0 interrupts on same scanline
9. TAC=5 TIMA=-20 sets IF in 80 cycles; can sync to timer by writing
   and reading 3 cycles later
10. Writes to VRAM in mode 3 or OAM in mode 2/3 don't take effect
11. `ei push bc pop bc ldh [rIF], a halt` with IE=A=$04 puts
    return address in stack red zone
12. `di halt` with TAC=IE=$04 and TIMA=IF=$00 sets IF bit 2
13. `di halt inc d halt inc e` double-increments only E (halt bug)
14. `di halt inc d halt inc e` calls no handler (VBA halt bug)
15. `ld a, 5 add a daa` does not produce half carry
16. Writing DIV every 1000 cycles or faster keeps APU length counter
    from expiring (suggested by LIJI)
17. APU off clears readable registers
18. NR52 bits 6-0 are read-only
19. `push bc pop af push af pop de` sets DE=BC&$FFF0
20. `inc hl` in mode 2 corrupts OAM only on DMG
21. Wave RAM can't be read back during a wave note (cf. Demotronic
    "NO BOY" and Blargg dmg_sound 09)
22. Alternating `ei di` calls no handler (VBA-M regression vs. VBA)
23. STAT=LYC+hblank+OAM causes halt in hblank on line LYC-1 to extend
    into hblank on LYC+1
24. Writes to echo RAM ($E000-$FDFF) affect corresponding WRAM byte

Unranked, to be tested at title screen and in menus:

- Joypad interrupt works at all
- Joypad interrupt happens at different LY values (Telling LYs?)
- Asserting P14/P15 while holding a button causes joypad interrupt
  (suggested by Daid)

Unranked, possibly model-specific:

- GBC palette can be written and read back during vblank only on GBC
- Whether disabling sprites in LCDC changes mode 3 duration
- Writing anything to STAT during mode 3 outside LYC causes an
  immediate extra interrupt only on DMG (suggested by organharvester)

Unranked:

- Approximate mode 3 duration with 0 and 10 sprites
- Something something mid-scanline WX changes (suggested by LIJI)
- Enabling hblank and OAM in STAT causes one interrupt, not two

Results
-------
Divergence between GB and GBC becomes more noticeable starting in
stage 3.  Because the GBC features of No$gmb are paywalled,  we do
not list results for No$gmb past stage 2.

Emulator     | Stage 1 | Stage 2 | Stage 3
------------ | ------: | ------: | ------:
emulicious   |  10/10  |  10/10  |   4/4
sameboy      |  10/10  |  10/10  |   4/4
bgb          |  10/10  |   9/10  |   4/4
mesen-s      |  10/10  |   9/10  |   3/4
gambattehawk |  10/10  |   9/10  |   4/4
gambatte     |  10/10  |   9/10  |   4/4
mgba         |  10/10  |   9/10  |   4/4
vba-m        |  10/10  |   8/10  |   1/4
gnuboy       |   7/10  |   4/10  |   3/4
goomba       |   5/10  |   5/10  |   1/4
kigb         |   3/10  |   6/10  |   3/4
no$gmb       |   0/10  |   7/10  |**$**/4
vba          |   6/10  |   1/10  |   1/4
rew.         |   2/10  |   2/10  |   2/4

