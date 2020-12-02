Game Boy coin ideas
===================

[TASVideos GB Accuracy Tests] lists a set of Game Boy emulator test
ROMs by Blargg that measure CPU-visible behaviors.  The tests show
the following results in NO$GMB in DMG mode:

- CPU Instrs: 9 of 11 pass
- DMG Sound 2: 0 of 12 pass
- Instr Timing: Fail
- Mem Timing 2: 0 of 3 pass
- OAM Bug 2: LCD Sync fails, rendering others unmeasurable

I plan to research the reason behind each failure in order to
understand how the behavior of the NO$GMB fantasy console differs
from that of a Game Boy.  Then I'll turn the differences most likely
to affect game behavior into coins.

Each stage has 10 coins.  I want stage 1 to be the ten most impactful
things that NO$GMB fails.  Stage 2 can have things that NO$GMB passes
so long as they're impactful and another notable emulator fails them.

[TASVideos GB Accuracy Tests]: http://tasvideos.org/EmulatorResources/GBAccuracyTests.html

CPU instructions
----------------
Blargg's CPU instructions test shows that NO$GMB produces incorrect
flags for two categories of instructions: `op sp, hl` (adding an
8-bit signed value to SP) and `op rp` (adding a 16-bit register pair
to HL).  Though this test is CRC-driven like ZEXALL, one can load the
following instructions into the exerciser to make a quick spot check:

- 19: `add hl, de`
    - GB: Z unchanged, N = 0, HC = carry from bits 11 and 15 of HL + HL
    - NO$GMB: N and H unchanged
- 29: `add hl, hl`
    - GB: Z unchanged, N = 0, HC = carry from bits 11 and 15 of HL + HL
    - NO$GMB: N and H unchanged
- E8 rr: `add sp, rel`
    - GB: Z = N = 0, HC = carry from bits 3 and 7 of (SP & $FF) + rr
    - NO$GMB: C = bit 7 of rr
- F8 rr: `ld hl, sp+rel`
    - GB: Z = N = 0, HC = carry from bits 3 and 7 of (SP & $FF) + rr
    - NO$GMB: C = bit 7 of rr

If it's any comfort, NO$GMB does a lot better than TGB Dual, and it
passes Blargg's `daa` test for all values of AF.  I'm told VBA has
had problems with `daa`; it may be worth a stage 2 coin.

- 27: `daa`
    1. `low_correction` is $06 if H true or (A & $0F) in A-F else $00
    2. `high_correction` is $60 if C true or A in $9A-$FF else $00
    3. Add or subtract `low_correction | high_correction` based on N
    4. Z = A == 0, N unchanged, H = 0, C set if correction add/sub
       overflowed or if already set (`daa` never clears C)

DMG sound
---------
None of these pass because NO$GMB provides incorrect values when
reading back values from audio registers.  Reverse engineering
what it actually does and what misbehaviors would be most
game-visible will be fun.

In the exerciser, use these instructions to explore APU reset:
```
INST E21FE2F01100, AF 0010, BC 0026
  ; Disassembly of above
  ld [$FF00+C], a  ; Turn off APU, clearing all regs
  rra              ; Put 1 in bit 7
  ld [$FF00+C], a  ; Turn on APU
  ldh a, [$FF11]   ; Audio regs are FF10-FF25
```

This was used to confirm the OR mask pattern in Blargg's test, of
which NO$GMB observes only the last byte:
```
803F00FFBF FF3F00FFBF 7FFF9FFFBF FFFF0000BF 000070
```

Halt bug
--------
Like 65816 and unlike Z80, SM83 has a `halt` instruction that works
while interrupts are disabled.  (My code refers to this as a
`di halt`.) If an interrupt is already pending, however, the byte
following `halt` will be read twice: as two instructions or as an
opcode and its operand.

NO$GMB passes this.  Make it a stage 2 coin.

Instruction timing
------------------
The Game Boy has three incrementing timers.  Blargg's instruction
timing test uses one of them to measure CPU instructions' duration.
If timers behave inconsistently, each instruction will appear to have
different timing relative to each timer.  This can be used to make
multiple coins.

- DIV ($FF04) increases every 64 cycles, wrapping from 255 to 0.
  This is bits 13-6 of an internal timer whose falling edges are used
  to clock noise, volume envelopes, pulse 1 sweep, and TIMA
  increment.  Writing any value clears this entire timer.
- TIMA ($FF05) increases every 256, 4, 16, or 64 cycles, based on
  bits 1-0 of TAC ($FF07), wrapping from 255 to TMA ($FF06).
  If bit 2 of TAC is false, TIMA does not increase.
- LY ($FF44) increases every 114 cycles (228 in double speed mode)
  while the LCD is on ($FF40).

This test is supposed to finish in half a second.  It begins with an
11-cycle loop in `start_timer` ($C2D6) that tries to synchronize to
the 4-cycle phase by writing 0 and reading it 3 cycles later, trying
again if it incremented.  I guess (need to trace in bgb) that on the
Game Boy, this succeeds within four tries.  On NO$GMB, it always
increments and thus gets stuck, and the test has no timeout for this.
There's also a suggestion that DIV goes _backwards_ on NO$GMB, which
would interfere with games' random number generators.

TODO:
- See if TIMA in 64-cycle mode always has the same phase as DIV
- Ask gbdev #emudev which games depend on working timers

Memory timing
-------------
Instructions that access memory do so on the _last_ cycles of an
instruction.  This includes read instructions, write instructions,
and read-modify-write instructions.

Blargg's memory access timing test synchronizes to a 64-cycle TIMA,
waits a variable amount of cycles, and executes each instruction with
TIMA as the address to determine on which cycle the access occurs.
Based on how TIMA reacts, it determines whether the access occurred
before or after the increment.

Because it relies on correct timers, which NO$GMB lacks, a different approach will be needed.

TODO: Ask gbdev #emudev which games actually depend on working memory timing

OAM bug
-------
The NES PPU's object attribute memory (OAM) controller is broken.
So is that of the monochrome Game Boy.  It copies one 8-byte pair of
entries over another pair if the program is not careful.  On the
Game Boy, the trigger is an increment or decrement operation on a
16-bit register pair (BC, DE, HL, or SP) while the pair's value is in
the range $FF00 to $FFFF during OAM scan (the first 80 dots of lines
0-143 while the LCD is on).  Affected instructions are `inc`, `dec`,
`push`, `pop`, and autoincrementing `ld`.  It _doesn't_ happen for
`ld hl, sp+`, `add sp`, or `add hl`, or at any time other than OAM scan.

My guess at the mechanism is that the incrementer puts the value on
the internal address bus without RD or WR, and the OAM controller
isn't equipped to ignore being decoded without RD or WR.

NO$GMB is incompatible with the method that Blargg's test uses to
synchronize to the start of frame at $C0BF.  LY advanced 109 debug
clocks after the instruction that turns on the LCD, not 114 as
expected.  I also noticed that DIV changes greatly when LCD is turned
back on.

Incidentally, bgb fails most of this too, but probably for different
reasons.

