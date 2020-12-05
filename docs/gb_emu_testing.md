Game Boy coin ideas
===================

Many free or freeware Game Boy emulators fail accuracy test ROMs due
to behavior differences from authentic hardware.  I plan to research
the precise behaviors underlying test failures and then produce
"coins", or minimal test routines to highlight these differences.

Coin criteria
-------------
What makes a good coin?

- Each of 10 stages has 10 coins, each of which represents testing
  one hardware behavior that at least one stable emulator fails.
- Stage 1 can be cleared if up to 5 coins are missed.  Later stages
  allow missing up to 10 coins from it and previous stages combined.
- Tests in earlier stages should cover behaviors with a greater
  impact on compatibility with released software or common homebrew
  programming gotchas.  Later stages can nitpick harder.
- Tests in one stage should not assume results from a later stage.
- Stage 1 should be the ten most impactful things that NO$GMB fails
  in "as in reality" mode and which do not vary between GB and GBC.
  (I want the "no cash" gimmick to work even without a license file.)
- Tests should quickly demonstrate a failure, preferably within
  two frames (35000 M-cycles) and a handful of ROM bytes.  Better
  characterization of the "fantasy console" implemented by each
  emulator reduces the need for exhaustive testing.

Installing emulators
--------------------
I'm operating under the premise of "no cash."  This means no
production Windows license and no paid versions of emulators.
NO$GMB and BGB are available only for Windows, and the Linux build
of KiGB is a few versions back.  I'm testing them in Wine 5.0.2 as
provided by Ubuntu 20.04 LTS.

KiGB saves key bindings and other settings in the current working
directory, not the executable's directory (as if a portable app)
or the user's local settings directory (as if installed).

Now that SCons has transitioned to Python 3, the `SConstruct`
file for classic [Gambatte] needs a change before it will build:
```
-               version_str_def = [ 'GAMBATTE_SDL_VERSION_STR', r'\"r' + git_revno + r'\"' ]
+               version_str_def = [ 'GAMBATTE_SDL_VERSION_STR', r'\"r' + git_revno.decode("utf-8") + r'\"' ]
```

The [BizHawk] version of [Gambatte-Speedrun] was used in order to use
the replacement BIOS file from SameBoy.  Upstream Gambatte-Speedrun
rejects BIOS files that are not bit-identical to Nintendo's
copyrighted BIOS file, and unlike with the Game Boy Advance BIOS,
there is no loophole through which to dump the Game Boy Color BIOS
through the Game Pak slot.

[VisualBoyAdvance] 1.7.2 for Windows (from before the VBA-M fork)
requires mfc42.dll.  This is part of the Microsoft Visual C++ 6
redistributable package, sometimes called [vcredist].

The [Goomba Color] ROM builder is written in Visual Basic 6 and needs
the [Visual Basic 6 runtime].  Skip it.  Just use `cat` 😸️
```
$ cat goomba.gba libbet.gb gb240p.gb exerciser.gb > magicflr.gba
C:\>copy /b goomba.gba+libbet.gb+gb240p.gb+exerciser.gb magicflr.gba
```

[Gambatte]: https://github.com/sinamas/gambatte
[Gambatte-Speedrun]: https://github.com/pokemon-speedrunning/gambatte-speedrun
[VisualBoyAdvance]: https://sourceforge.net/projects/vba
[vcredist]: https://jrsoftware.org/iskb.php?vc
[Goomba Color]: https://www.dwedit.org/gba/goombacolor.php
[Visual Basic 6 runtime]: https://www.microsoft.com/en-us/download/details.aspx?id=24417

Emulator test results
---------------------
[TASVideos GB Accuracy Tests] lists a set of Game Boy emulator test
ROMs by Blargg that measure CPU-visible behaviors.  The tests show
the following results in NO$GMB final, VisualBoyAdvance 1.7.2,
Goomba Color 2019-05-04, KiGB v2.05, BGB 1.5.8,
VisualBoyAdvance-M 2.1.4, Gambatte r696, BizHawk 2.5.2 Gambatte,
and mGBA 0.9-6554-a2cd8f6cc:

- CPU Instrs  
  VBA 6 of 11; NO$GMB and KiGB 9 of 11; VBA-M, BGB, mGBA, and Goomba pass
- DMG Sound  
  KiGB _crashes;_ NO$GMB and VBA 0 of 12; Goomba 1 of 12; VBA-M 7 of 12; mGBA 10 of 12; BGB passes
- Halt Bug  
  VBA enters a reset loop; KiGB and Goomba fail; others pass
- Instr Timing  
  NO$GMB and KiGB hang; Goomba fails #255; VBA-M, BGB and mGBA pass
- Mem Timing 2  
  KiGB _crashes;_ VBA, NO$GMB, and Goomba 0 of 3; VBA-M 2 of 3; BGB and mGBA pass
- OAM Bug  
  VBA, NO$GMB, KiGB, and Goomba fail LCD Sync, rendering others unmeasurable;
  VBA-M, BGB, and mGBA 3 of 8

SameBoy v0.13.6 passes everything.  Results of Gambatte Classic and
BizHawk Gambatte are identical to BGB.

VBA is a train wreck.  The Hill zone test of 144p Test Suite freezes,
and _Libbet and the Magic Floor_ doesn't even boot.

These emulators have not yet been tested:

- VisualBoyAdvance individual CPU Instrs
- Mesen-S (pending fix of settings not saving in Mono version)
- GameYob and Lameboy in DeSmuME or MelonDS
- helloGB
- REW
- TGB Dual
- Virtual GameBoy by Marat

Some notes from research into behavior differences follow:

[TASVideos GB Accuracy Tests]: http://tasvideos.org/EmulatorResources/GBAccuracyTests.html

CPU instructions
----------------
Blargg's CPU instructions test shows that both NO$GMB and KiGB
produce incorrect flags for two categories of instructions:
`op sp, hl` (adding an 8-bit signed value to SP) and `op rp` (adding
a 16-bit register pair to HL).  Rather than giving details of what
went wrong, this test just does a CRC over the results like ZEXALL.
This led to the development of the exerciser.  One can load the
following instructions into the exerciser to make a quick spot check:

- 19: `add hl, de`
    - GB: Z unchanged, N = 0, HC = carry from bits 11 and 15 of HL + DE
    - NO$GMB and KiGB: N and H unchanged
- 29: `add hl, hl`
    - GB: Z unchanged, N = 0, HC = bits 11 and 15 of HL
    - NO$GMB and KiGB: N and H unchanged
- E8 rr: `add sp, rel`
    - GB: Z = N = 0, HC = carry from bits 3 and 7 of (SP & $FF) + rr
    - NO$GMB and KiGB: C = carry from bit 15 of SP + sext8to16(rr)
- F8 rr: `ld hl, sp+rel`
    - GB: Z = N = 0, HC = carry from bits 3 and 7 of (SP & $FF) + rr
    - NO$GMB and KiGB: C = carry from bit 15 of SP + sext8to16(rr)

If SP is not pointing into HRAM, the carry from E8 and F8 in NO$GMB
and KiGB will always equal bit 7 of the relative value.

If it's any comfort, NO$GMB and KiGB do better than VBA and TGB Dual.
They pass Blargg's `daa` test for all values of AF.

- 27: `daa`
    1. `low_adjust` is $06 if H true or (A & $0F) in A-F else $00
    2. `high_adjust` is $60 if C true or A in $9A-$FF else $00
    3. Add or subtract `low_adjust | high_adjust` based on N
    4. Z = A == 0, N unchanged, H = 0, C set if adjust add/sub
       overflowed or if already set (`daa` never clears C)

VBA `daa` runs AF through a big lookup table.  Adding $95 and $05 on
a Game Boy produces AF=$9A00, which `daa` adjusts to $0090 (Z and
C flags set).  VBA adjusts $9A instead to $00B0 (Z, H, and C set).
An exhaustive `daa` tester to find error patterns may be useful.

DMG sound
---------
NO$GMB fails all tests because it doesn't mask write-only bits when
reading back values from audio registers and honors writes while the
APU is off.  Still curious what are the most impactful differences.

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

Game Boy, VBA-M, mGBA, and NO$GMB all make most sound registers
readable, clear sound registers to 0 when the APU is turned off, and
read NR52 unused bits 6-4 as 1.  Unlike the others, NO$GMB honors
writes to other registers while the APU is off, and it doesn't hide
lengths, periods, or other unused bits from being read back.
In fact, NO$GMB allows reading out the pitch as sweep updates it.

Game Boy, VBA-M, mGBA, and NO$GMB all reflect channel status in NR52
bits 3-0, which turn off when its length counter (NRx1) expires or
wave RAM is unlocked (NR30), and don't turn off when output volume
fades to 0.  Unlike the others, NO$GMB leaves the status bit on
when the sweep decreases pulse 1's frequency to minimum or when
pulse or noise envelope starting value (NRx2) is less than 8.

VBA-M passes dmg_sound 1 through 7 and fails 8 (01), 9 (01), 10 (01),
11 (04), and 12 (01).  mGBA passes all but 7 (05) and 10 (01).
This is the first time I saw a ROM crash an emulator, though I admit
I was using KiGB v2.05 in Wine because Linux is stuck at v2.02.

Halt bug
--------
**Not in stage 1 because NO$GMB passes.**

Like 65816 and unlike Z80, SM83 has a `halt` instruction that works
while interrupts are disabled.  (My code refers to this as a
`di halt`.) If an interrupt is already pending, however, the byte
following `halt` will be read twice: as two instructions or as an
opcode and its operand.

Most emulators' behavior can be characterized with this exerciser:
```
INST E27614761C00, AF 0700, BC 0007, IEIF 0100
; Disassembles to
ld [$FF00+c], a  ; Set timer mode to 7 for use with IE 04
halt
inc d  ; If no interrupt is pending, this runs once
halt
inc e  ; This runs twice because an interrupt is still pending
; ei   ; Change last byte to FB to see queued interrupts get handled
```
Because NO$GMB and most others behave like a Game Boy, stage 1 does
not test `halt`.  Because KiGB and Goomba differ, stage 2 tests it so
that later tests relying on more precise timing can use `di halt`.
VBA is a clown show: with IME off, it can _call the handler anyway._

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

This test finishes in half a second on Game Boy, VBA-M, and mGBA.
It begins with an 11-cycle loop in `start_timer` ($C2D6) that tries
to synchronize to the 4-cycle phase by writing 0 and reading it 3
cycles later, trying again if it incremented.  I guess (need to
trace in bgb) that on the Game Boy, this succeeds within four tries.
On NO$GMB, it always increments and thus gets stuck, and the test
has no timeout for this.  There's also a suggestion that DIV goes
_backwards_ on NO$GMB, which would interfere with games' random
number generators.

This exerciser locks TIMA in 64-cycle mode to the same phase as DIV.
Run this first:
```
INST E2AF22222200, AF 0700, BC 0007, HL FF04
# disassembles to
ld [$FF00+c], a
xor a
ld [hl+], a  ; reset DIV
ld [hl+], a  ; set TIMA value to 0
ld [hl+], a  ; set TIMA overflow reload to 0
```
Then run this repeatedly:
```
INST 0520FD2A1B46, BC 0100, HL FF04
# disassembles to
label:
dec b        ; wait 4*B cycles
jr nz, label
ld a, [hl+]  ; read DIV
inc de       ; burn a couple cycles
ld b, [hl]   ; read TIMA 4 cycles after DIV
```
A (DIV) and B (TIMA) should be the same on most presses, with B one
higher on a small fraction.  Everything but NO$GMB gets this right.

TODO: Ask gbdev #emudev which games depend on working timers

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

Because it relies on correct timers, which NO$GMB lacks, a different
approach will be needed.

VBA-M fails 3 (01).

TODO: Ask gbdev #emudev which games actually depend on working memory timing

OAM bug
-------
**Not in stage 1 because GBC is not affected.**

The NES PPU's object attribute memory (OAM) controller is broken.
So is that of the monochrome Game Boy.  It copies one 8-byte pair of
entries over another pair if the program is not careful.  On the
Game Boy, the trigger is an increment or decrement operation on a
16-bit register pair (BC, DE, HL, or SP) while the pair's value is in
the range $FF00 to $FFFF during OAM scan (the first 80 dots of lines
0-143 while the LCD is on).  Affected instructions are `inc`, `dec`,
`push`, `pop`, and autoincrementing `ld`.  It _doesn't_ happen for
`ld hl, sp+`, `add sp`, or `add hl`, at any time other than OAM scan,
or on Game Boy Color in either mode.

My guess at the mechanism is that the incrementer puts the value on
the internal address bus without RD or WR, and the OAM controller
isn't equipped to ignore being decoded without RD or WR.

NO$GMB and KiGB fail the LCD sync test for timing consistency, making
the other tests invalid.  Running the test in NO$GMB's debugger shows
the emulator is incompatible with the method that Blargg's test uses
to synchronize to the start of frame at $C0BF.  LY advanced 109
debug clocks after the instruction that turns on the LCD, not 114 as
expected.  I also noticed that DIV changes greatly when LCD is turned
back on.  KiGB also fails, and it has no debugger to explain why.

VBA-M, mGBA, and even bgb 1.5.8 all fail 2 (02), 4 (03), 5 (02),
7 (01), and 8 (02): everything but LCD sync and the non-cause tests.

Other tests
-----------
Things I can think off the top of my head to make exercisers for:

- DIV and TIMA sync
- DAA error visualizer
- Readback of BGP, OBP0, OBP1
- In which modes OAM and VRAM can be read and written

Coin list
---------
All this is preliminary.

1. `add hl` flags
2. `add sp` flags
3. APU off clears registers and doesn't honor writes till turned on
4. Filling APU with zeroes causes OR mask to be read back
5. Upward sweep turns off NR52 status and downward sweep doesn't
6. APU length counter expiry and envelope $00 turn off NR52 status
7. 
8. 
9. 
10. 
11. `di halt inc d halt inc e` double-increments only E (halt bug)
12. `di halt inc d halt inc e` calls no handler (VBA halt bug)
13. `inc hl` in mode 2 corrupts OAM only on DMG, and GBC palette can
    be written and read back during vblank only on GBC
14. `daa` with $9A00 and a few other key values of AF
15. 
16. 
17. 
18. 
19. 
20. 

