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
Lists for the first three stages are complete.  Stage 4 is in
planning and begins a focus on distinguishing behaviors of the
original Game Boy (DMG) from later models.

Stages:

1. no$gmb
2. VBA and rew.
3. Mid-tier emulators
4. Game Boy Color (GBC)-specific behaviors
5. Super Game Boy (SGB)-specific behaviors

Coins:

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
15. `ld a, 5 add a daa` leaves half-carry clear
16. Writing DIV every 1000 cycles or faster keeps APU length counter
    from expiring (suggested by LIJI)
17. APU off clears readable registers
18. NR52 bits 6-0 are read-only
19. `push bc pop af push af pop de` sets DE=BC&$FFF0
20. `inc hl` in mode 2 corrupts OAM only on DMG/SGB
21. Wave RAM can't be read back during a wave note (cf. Demotronic
    "NO BOY" and Blargg dmg_sound 09)
22. Alternating `ei di` calls no handler (VBA-M regression vs. VBA)
23. STAT=LYC+hblank+OAM causes halt in hblank on line LYC-1 to extend
    into hblank on LYC+1
24. Writes to echo RAM ($E000-$FDFF) affect corresponding WRAM byte
25. Unused I/O register bits read back with an OR mask
26. Approximate mode 3 duration with 0, 10, and 16 sprites
27. 4 kHz timer turning on and off every 12 cycles eventually counts
    up past $FF
28. At start, NR52=$F0 on SGB or $F1 elsewhere (breaks SGB detection
    in LSDJ)
29. Joypad interrupt works at all
30. `daa` produces correct results for pathological values of AF:
    $9A NH to $00 ZC, $7A H to $80, $00 NHC to $9A NC to $3A NC
31. Retriggering wave channel without turning off its DAC corrupts
    wave RAM only on DMG
32. Copying 114 tiles with DMA takes 8 scanlines
33. STAT=$00 during hblank, vblank, or LY=LYC causes an immediate
    extra interrupt only on DMG (suggested by organharvester)
34. VRAM has banks 0 and 1 and WRAM has banks 1-7, only on GBC
35. OR mask for GBC-specific registers varies by model, particularly
    KEY1, SC, and RP (suggested by beware)
36. Disabling sprites in LCDC shortens mode 3 only on DMG
37. During OAM DMA from WRAM, reading ROM produces valid data on GBC
    and whatever the DMA unit is reading on DMG
38. DMG receives writes to length counters while APU is turned
    off in NR52, and GBC does not
39. GBC palette can be written and read, storing all 8 bits of all
    128 bytes, auto-incrementing on writes to $80-$FF (not on $00-$7F
    or reads) with wrapping, only on GBC (suggested by sylvie/zlago)
40. GBC palette can be written and read on GBC only outside mode 3,
    and write increments address even in mode 3 (suggested by
    nitro2k01 and sylvie/zlago)

Unranked, to be tested at title screen and in menus:

- Joypad interrupt happens at different LY values (Telling LYs?)
- Asserting P14/P15 while holding a button causes joypad interrupt
  (suggested by Daid)

Stage 5 shall focus on SGB.  It can be hard to test because so much
of the SGB is open-loop, passing no feedback to the Game Boy SoC.

- `MLT_REQ` does not initiate multiplayer on GBC (GBC+SGB mode is
  not authentic)
- P1 rise time differences among DMG/MGB, SGB, and GBC/GBA
- Joypad interrupt timing is predictable on SGB/SGB2 (at least in
  60 Hz) and not so on handhelds
- Which of P14 and P15 advances to the next player in SGB multiplayer
- `JUMP` does anything at all on SGB only

Unranked:

- Something something mid-scanline WX changes (suggested by LIJI)
- `di halt halt halt` keeps reading the last `halt` until something
  changes the last `halt` to a non-`halt` opcode, such as VRAM
  inaccessibility (see [double halt cancel] by nitro2k01)
- Consider a stage of GBC double speed tests: CPU speed, timer/DIV
  speed, APU speed, mode 3 length, GDMA vs. HDMA vs. OAM DMA speed
- Does `halt` pause GBC DMA?
- How much time HDMA takes from a scanline
- APU length counters do not automatically reload per note the
  way TIMA reloads from TMA.  If NRx1 is not rewritten, a second
  consecutive note lasts the maximum length: 1 s (wave) or 1/4 s
  (pulse or noise).
- APU length counters continue to tick after rewriting NRx1, even
  after the length counter has stopped the note, so long as the
  length counter isn't paused by turning off NRx4 bit 6.

To make things easier for some emulator developers during long
periods of development hiatus due to the day job of Numism's
maintainer, it has been suggested to prototype SGB coins in a
separate ROM and merge them once complete.

[double halt cancel]: https://github.com/nitro2k01/little-things-gb/tree/main/double-halt-cancel

Results
-------
Test each emulator in DMG, SGB, and GBC mode, and record the lowest
score among supported modes.
Also record the highest score if at least twice the lowest or 10
coins more than the lowest.
Use SameBoot in emulators requiring a 256- or 2048-byte boot ROM, and
use 256 KiB system software dumped from an authentic SGB accessory
if required.
Disregard coins not yet implemented, marked "NYA" or "Always pass".

Divergence between DMG and GBC behavior becomes more noticeable
starting in stage 4.  Because the GBC features of No$gmb are
paywalled, we do not list results for No$gmb past stage 3.

Emulator     | Stage 1 | Stage 2 | Stage 3 | Stage 4 | Notes
------------ | ------: | ------: | ------: | ------: | -----
sameboy      |  10/10  |  10/10  |  10/10  |   7/7   |
emulicious   |  10/10  |  10/10  |  10/10  |   6/7   | No SGB
bgb          |  10/10  |  10/10  |  10/10  |   6/7   |
mesen2       |  10/10  |  10/10  |  10/10  |   5/7   | SGB low-level emulation
gambatte     |  10/10  |   9/10  |   9/10  |   7/7   |
mgba         |  10/10  |   9/10  |   8/10  |   5/7   |
vba-m        |  10/10  |   8/10  |   5/10  |   6/7   |
kigb         |   3/10  |   6/10  |   6/10  |   6/7   |
gnuboy       |   6/10  |   5/10  |   6/10  |   2/7   |
peanut-gb    |   4/10  |   5/10  |   2/10  |   6/7   |
goomba       |   5/10  |   6/10  |   3/10  |   2/7   |
vba          |   6/10  |   1/10  |   2/10  |   3/7   |
no$gmb       |   0/10  |   7/10  |   4/10  |**$**/10 | GBC paywall
jsgb         |   3/10  |   3/10  |   3/10  |   3/7   | Four pauses for `di halt`
rew.         |   2/10  |   2/10  |   4/10  |   3/7   |
