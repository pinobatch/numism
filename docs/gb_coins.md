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
All this is preliminary:

1. `add hl` flags
2. `add sp` flags
3. APU writes while off not honored, before or after turning back on
4. Filling APU with zeroes causes OR mask to be read back
5. Upward sweep turns off NR52 status and downward sweep doesn't
6. APU length counter expiry and envelope $00 turn off NR52 status
7. DIV increases by 1 unit per period
8. 
9. 
10. 
11. `ei push bc pop bc ldh [rIF], a halt` with IE=A=$04 puts
    return address in stack red zone
12. `di halt` with TAC=IE=$04 and TIMA=IF=$00 sets IF bit 2
13. `di halt inc d halt inc e` double-increments only E (halt bug)
14. `di halt inc d halt inc e` calls no handler (VBA halt bug)
15. `ld a, 5 add a daa` does not produce half carry
16. 
17. APU off clears readable registers
18. NR52 bits 6-0 are read-only
19. `push bc pop af push af pop de` sets DE=BC&$FFF0
20. `inc hl` in mode 2 corrupts OAM only on DMG
21. GBC palette can be written and read back during vblank only on GBC

