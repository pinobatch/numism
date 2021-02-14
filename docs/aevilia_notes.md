Emulator detection in Aevilia
=============================

This canceled RPG for Game Boy Color displays a rough assessment of
emulation quality on its file select screen.  Code in [home.asm]
calculates the assessment using the following procedure:

```
If starting A != $11:
  Lock up with polite message about being GBC-only
If value written to $C000 not read from $E000:
  Display skippable VBA warning
  Return "crappy emulator"
Write 0 to $FF6C (GBC-only register used by boot ROM)
If value at $FF6C != $FE:
  Write a value to $D000 in WRAM bank 1.
  If it matches value at $D000 in WRAM bank 2:
    (A user of certain flash cart menus may encounter this screen.)
    Lock up with a more scolding message against trying to play
    GBC-only games in reduced functionality mode, worded so as to
    lie to Super Game Boy users
  Increment rHDMA1. If it took (shouldn't on GBC):
    Return "decent emulator"
  Return "Nintendo 3DS"
Enable STAT mode 2 as the only interrupt
For B in [$00, $10]:
  Set up HDMA addresses from $E0E0 in Echo RAM to $8800+B in main RAM
  (DMA from echo RAM appears to do open bus)
  Clear rIF
  di halt
  Write $80 to start HDMA with one 16-byte unit
  Wait exactly enough cycles for HDMA to start
  If B != 0, wait one extra cycle
  (The first byte of each DMA catches opcode bits)
Read the two 16-byte results from $8800-$881F
If these are 16 copies of the opcode executed when interrupted:
  Return "GBC" or "GBA" depending on starting B
Return "awesome emulator"
```

As of February 2021, Numism incorporates the echo RAM test.
The $D000 aliasing, $FF6E writability, HDMA readability, and HDMA
timing tests all cover GBC-exclusive features and are thus reserved
for later stages.

[home.asm]: https://github.com/ISSOtm/Aevilia-GB/blob/9b4e233bac6fbf175ca9ae7e4c0a8f16c8222275/home.asm
