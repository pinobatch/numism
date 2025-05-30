Game Boy emulator testing
=========================

I'm testing several current and historic emulators of the Game Boy
compact video game system to compare and contrast their behavior
with that of an authentic Game Boy.  I seek to produce "coins,"
my term for short test programs to highlight a behavior difference.
(See [What makes a good coin?] and [Game Boy coin list].)
Along the way, I'm producing [exercisers], or in-depth test ROMs
used to help me document specific differences.

[What makes a good coin?]: ./good_coin.md
[Game Boy coin list]: ./gb_coins.md
[exercisers]: ../gameboy/exerciser/README.md

Emulators under test
--------------------
For the sake of reproducibility, I'm operating under the principle of
"no cash."  This means no paid operating systems nor paid emulators.
Thus I'm running tests on Ubuntu, a GNU/Linux distribution.

These are built from source:

* [Gambatte-Speedrun (Non-PSR)](https://github.com/pinobatch/gambatte-speedrun) r738
* [gnuboy](https://github.com/rofl0r/gnuboy) 1.0.3
* [mGBA](https://mgba.io/) 0.10-7008-3159f2ec5
* [SameBoy](https://sameboy.github.io) 0.14.3
* [VisualBoyAdvance-M](https://vba-m.com/) 2.1.4

These are run in Wine 9.12 (as provided by WineHQ for Ubuntu 24.04):

* [BGB](https://bgb.bircd.org/) 1.6
* [KiGB](http://kigb.emuunlim.com/) 2.05
* [No$gmb](https://problemkaputt.de/gmb.htm) 2.5
* [rew.](https://www.emuparadise.me/emulators/gb.php) 12STX
* [VisualBoyAdvance](https://sourceforge.net/projects/vba) 1.7.2

This is run in .NET 8:

* [Mesen](https://github.com/SourMesen/Mesen2) 2.nightly

This is run in OpenJDK 17:

* [Emulicious](https://emulicious.net/)

This is run in mGBA:

* [Jagoomba Color](https://github.com/EvilJagaGenius/jagoombacolor) 0.5

This is run in Firefox:

* [JSGB by Pedro Ladaria](https://github.com/bleepbloop/JsGB) v0.02

For two emulators (No$gmb and rew.), I have not been able
to get them to take a ROM on the command line.  Only `File > Open...`
(however labeled) works.

In a chat on 2021-03-01, BGB developer Beware provided a couple tips:

- (From game display) Esc, F5: Open VRAM viewer
- (From debugger) Shift+F9, Esc: Temporarily disable exceptions

I use KiGB for Windows because KiGB for Linux is three versions back.
KiGB saves key bindings and other settings in the current working
directory, not the executable's directory (as if a portable app)
or the user's local settings directory (as if installed).  I have
created a script to change to KiGB's directory before running a ROM.

In July 2021, Gambatte developer Sinamas stepped down and handed
maintenance to the _Pokémon_ speedrunning community, which publishes
GSR (formerly Gambatte-Speedrun).  This front end to Gambatte and
mGBA is opinionated, assuming that the user is attempting a speedrun
of a _Pokémon_ game with intent to verify it later on a Game Boy
Player.  To ensure cycle accuracy of the timers that _Pokémon_
relies on for random number generation, GSR requires a boot ROM
and rejects boot ROMs that are not bit-identical to Nintendo's
copyrighted boot ROM. Unlike with the Game Boy Advance BIOS, there
is no known loophole through which to dump the Game Boy Color boot
ROM through the Game Pak slot.  Instead, we use either BizHawk or
a forked front end that accepts SameBoot, the boot ROM of SameBoy.

VisualBoyAdvance 1.7.2 for Windows (from before the VBA-M fork)
requires `mfc42.dll`.  This is part of the Microsoft Visual C++ 6
redistributable package, sometimes called [vcredist].

The `goombafront` ROM builder is written in Visual Basic 6 and needs
the [Visual Basic 6 runtime].  Skip it.  Just use `cat` 😸️
```
$ cat jagoomba.gba libbet.gb gb240p.gb exercise.gb > magicflr.gba
C:\>copy /b jagoomba.gba+libbet.gb+gb240p.gb+exercise.gb magicflr.gba
```
Better yet, use a Bash script like this:
```
#!/bin/sh
set -e
tmpfile=$(mktemp /tmp/goombaXXXXXX.gba) || exit 1
trap "rm -f $tmpfile" EXIT
cat "/home/pino/develop/emulators/jagoomba.gba" "$1" > "$tmpfile"
mgba-qt "$tmpfile"
```

JSGB is tedious to test.  You have to put ROMs in a folder, change
`index.htm` to name them, and then start a web server so that JSGB
can have a well-defined origin through which to `XMLHttpRequest`
the ROMs.  We use the static server built into Python because the
test ROM build process already uses Python for font conversion.
```
python3 -m http.server & firefox http://localhost:8000
```
JSGB pauses emulation and shows an `alert()` box when reaching
`di halt`.  This exception is hardcoded in the emulator's CPU core.
Fortunately, stage 2 coins trip it only four times.  (The similarly
named [jsGB by Imran Nazar](https://github.com/Two9A/jsGB) went on
hiatus in August 2010 and never got far enough along in development
to be testable.)

[vcredist]: https://jrsoftware.org/iskb.php?vc
[Visual Basic 6 runtime]: https://www.microsoft.com/en-us/download/details.aspx?id=24417

Results of Blargg's emulator tests
----------------------------------
[TASVideos GB Accuracy Tests] lists a set of Game Boy emulator test
ROMs by Shay Green (known in the scene as Blargg) that measure
CPU-visible behaviors.  The tests show the following results in
No$gmb 2.5, VisualBoyAdvance 1.7.2, VisualBoyAdvance-M 2.1.4,
Goomba Color 2019-05-04, KiGB v2.05, BGB 1.6, rew. 12STX,
Mesen-S 0.4.0.66, Gambatte r696, BizHawk 2.5.2 Gambatte,
SDL2 gnuboy 1.0.3, and mGBA 0.9-6554-a2cd8f6cc:

- CPU Instrs  
  VBA 6 of 11; rew. 7 of 11; No$gmb and KiGB 9 of 11;
  gnuboy 10 of 11; VBA-M, BGB, mGBA, Mesen, and Goomba pass
- DMG Sound  
  KiGB _crashes;_ rew. hangs with 0 of 11; No$gmb, VBA, and gnuboy
  0 of 12; Goomba 1 of 12; VBA-M and Mesen-S 7 of 12; mGBA 10 of 12;
  BGB passes
- Halt Bug  
  VBA and rew. enter a reset loop; KiGB, Goomba, and gnuboy fail;
  others pass
- Instr Timing  
  No$gmb and KiGB hang; rew. and Goomba fail #255; gnuboy fails
  (34, 37); others pass
- Mem Timing 2  
  KiGB _crashes;_ VBA, No$gmb, rew., gnuboy, and Goomba 0 of 3;
  VBA-M 2 of 3; others pass
- OAM Bug  
  VBA, No$gmb, KiGB, Goomba, and gnuboy fail LCD Sync, rendering
  others unmeasurable; rew., VBA-M, Mesen, and mGBA 3 of 8.
  BGB passes since 1.5.10.

SameBoy has been passing everything since v0.13.6 if not earlier.

VBA is a train wreck.  The Hill zone test of 144p Test Suite freezes,
and _Libbet and the Magic Floor_ didn't even boot until a workaround
was added.

These emulators have not yet been tested:

- GameYob and Lameboy in DeSmuME or MelonDS
- helloGB
- TGB Dual
- Virtual GameBoy by Marat
- Gambatte deserves a retest in 2024

Some notes from research into behavior differences follow:

[TASVideos GB Accuracy Tests]: http://tasvideos.org/EmulatorResources/GBAccuracyTests.html

### CPU instructions

Blargg's CPU instructions test shows that both No$gmb and KiGB
produce incorrect flags for two categories of instructions:
`op sp, hl` (adding an 8-bit signed value to SP) and `op rp` (adding
a 16-bit register pair to HL).  Rather than giving details of what
went wrong, this test just does a CRC over the results like ZEXALL.
This led to the development of the exerciser.  One can load the
following instructions into the exerciser to make a quick spot check:

- 19: `add hl, de`
    - GB: Z unchanged, N = 0, HC = carry from bits 11 and 15 of HL + DE
    - No$gmb and KiGB: N and H unchanged
- 29: `add hl, hl`
    - GB: Z unchanged, N = 0, HC = bits 11 and 15 of HL
    - No$gmb and KiGB: N and H unchanged
- E8 rr: `add sp, rel`
    - GB: Z = N = 0, HC = carry from bits 3 and 7 of (SP & $FF) + rr
    - No$gmb and KiGB: C = carry from bit 15 of SP + sext8to16(rr)
- F8 rr: `ld hl, sp+rel`
    - GB: Z = N = 0, HC = carry from bits 3 and 7 of (SP & $FF) + rr
    - No$gmb and KiGB: C = carry from bit 15 of SP + sext8to16(rr)

```
INST 971900000000, AF 0000, HL 8800, DE 7800
; disassembles to
sub a  ; generate half carry and carry
add hl, de
; First inst can be SUB A (97) to set N and clear H,
; AND A (A7) to set H and clear N, or OR A (B7) to clear NH
; Vary DE: 77+88 is neither, 87+88 is C, 68+88 is H, 78+88 is HC

INST E8FEF5C1E8FE, SP D000
; disassembles to
add sp, -2
push af
pop bc     ; C bit 4 shows carry for D000+FFFE
add sp, -2 ; F bit 4 shows carry for CFFE+FFFE
```

If SP points outside HRAM, the carry from E8 and F8 in No$gmb
and KiGB practically always equals bit 7 of the relative value.

If it's any comfort, No$gmb and KiGB do better than VBA and TGB Dual.
They at least pass Blargg's `daa` test for all values of AF.
VBA, by contrast, fails the same two as No$gmb and KiGB plus these:

- 01-special `pop af` Failed #5
- 02-interrupts `halt` Failed #5
- 08-misc instrs F1 Failed
- 11-op a,(hl) 27 Failed

VBA fails two instructions in "01-special": `push af` and `daa`.
The broken `push af` also breaks `pop af` in "08-misc instrs".

- F1: `pop af`
    1. Read \[SP] into flags and increment SP
    2. Read \[SP] into A and increment SP
- F5: `push af`
    1. Decrement SP and then write A at \[SP]
    2. Decrement SP and then write flags & $F0 at \[SP]
- 27: `daa`
    1. If N == 0 and A >= $9A, set C
    2. If N == 0 and (A & $0F) >= $0A, set H
    3. `adjustment` is ($06 if H else $00) | ($60 if C else $00)
    4. Add `adjustment` if N is 0 or subtract `adjustment` if N is 1
    5. Z = A == 0, N unchanged, clear H to 0

VBA `push af` does not discard nonexistent bits 3-0 of flags.
```
INST C5F1F5D10000, BC 1301, SP D000
; disassembles to
push bc
pop af
push af
pop de
```

VBA `daa` causes a failure in "11-op a,(hl)".  If `push af` weren't
also broken, it'd also cause a failure in "01-special".  It works
by running AF through a big lookup table.  Adding $95 and $05 on
a Game Boy produces AF=$9A00, which `daa` adjusts to $0090 (Z and
C flags set).  VBA adjusts $9A instead to $00B0 (Z, H, and C set).

VBA and gnuboy fail "02-interrupts" at `halt`.  As described in
"Halt bug", this instruction behaves all kinds of wrong in VBA.
The test sets IE=$04 (timer), TAC=$05, TIMA=IF=0, does `halt nop`,
and looks for IF & $04 nonzero.  To demonstrate:
```
INST 327600000000, AF 0400, HL FF07, IEIF 0400
; disassembles to
ld [hl-], a  ; set TAC to 4
halt
```

Like VBA, rew. fails "01-special" and "11-op a,(hl)" because of `daa`
problems.  At least rew. gets flags right more often, particularly N.

Apart from VBA not clearing the H flag, VBA and rew. have no errors
on AF states that result from adding or subtracting two valid
BCD bytes.  Incorrect results come from pathological AF states,
such as carry with A >= $40.  Leave them for stage 3 or later.

Like No$gmb, rew. fails `add sp` and `ld hl, sp+`.  More worrying
is the failure on basic interrupt functionality.  It fails the
first test in "02-interrupts", which triggers an interrupt through
a write to IF.  It operates similarly to the following exerciser:
```
INST FBC5C1E22A46, AF 0400, BC 010F, HL CFFE, SP D000, IEIF 0400
; disassembles to
ei
push bc          ; initialize the red zone to 010F
pop bc
ldh [c], a       ; write $04 to IF, causing an interrupt
; Return address should point here, in HRAM
ld a, [hl+]
ld b, [hl]
```
The code reads the return address from the [stack red zone] into BA.
Game Boy loads the correct return address (AF=9400 BC=FF0F), whereas
rew. loads BC that was pushed (AF=0F00 BC=010F).  I doubt rew. is
honoring writes to IF at all.

[stack red zone]: https://en.wikipedia.org/wiki/Red_zone_(computing)

### DMG sound

No$gmb and VBA fail all tests because they don't mask write-only bits
when reading back values from audio registers and honor writes while
the APU is off.  Still curious what differences are most impactful.

Before I added a designated sound exerciser, I used these
instructions to explore APU reset:
```
INST E21FE2F01100, AF 0010, BC 0026
; disassembles to
ldh [c], a       ; Turn off APU, clearing all regs
rra              ; Put 1 in bit 7
ldh [c], a       ; Turn on APU
ldh a, [$FF11]   ; Audio regs are FF10-FF25
```
The resulting OR mask pattern matched that in Blargg's test,
of which No$gmb observes only the last byte:
```
803F00FFBF FF3F00FFBF 7FFF9FFFBF FFFF0000BF 000070
```

Game Boy, VBA-M, mGBA, and No$gmb all make most sound registers
readable, clear sound registers to 0 when the APU is turned off, and
read NR52 unused bits 6-4 as 1.  Unlike the others, No$gmb and VBA
honor writes to other registers while the APU is off and don't hide
lengths, periods, or other unused bits from being read back.  In
fact, No$gmb and VBA allow reading out the pitch as sweep updates it.
VBA doesn't mask NR52 unused bits; the last written value persists
until a note-on sets it or the length counter or sweep clears it.
Nor does VBA clear registers when the APU is turned off.

Game Boy, VBA-M, mGBA, and No$gmb all reflect channel status in NR52
bits 3-0, which turn off when its length counter (NRx1) expires or
wave RAM is unlocked (NR30), and don't turn off when output volume
fades to 0.  Unlike the others, No$gmb and VBA leave the status bit
on when pulse or noise envelope starting value (NRx2) is less than 8.
No$gmb doesn't even clear status when the sweep decreases pulse 1's
period to its ultrasonic minimum.

VBA-M passes dmg_sound 1 through 7 and fails 8 (01), 9 (01), 10 (01),
11 (04), and 12 (01).  mGBA passes all but 7 (05) and 10 (01).
KiGB is the first time I saw a Blargg ROM crash a GB emulator, and
I'm not sure how much is a KiGB bug and how much a Wine bug.

09 "Wave read while on" happens to be the same thing that the
"NO BOY! NO DEMO!" screen in _Demotronic_ demo by Megaboys tests.

### Halt bug

Like 65816 and unlike Z80, SM83 has a `halt` instruction that works
while interrupts are disabled.  (My code refers to this as a
`di halt`.) If an interrupt is already pending, however, the byte
following `halt` will be read twice: as two instructions or as an
opcode and its operand.

Most emulators' behavior can be characterized with this exerciser:
```
INST E27614761C00, AF 0700, BC 0007, IEIF 0100
; disassembles to
ldh [c], a  ; Set timer mode to 7 for use with IEIF 0400
halt
inc d       ; If no interrupt is pending, this runs once
halt
inc e  ; This runs twice because an interrupt is still pending
; ei   ; Change last byte to FB to see queued interrupts get handled
```
Because No$gmb and most others behave like a Game Boy, stage 1 does
not test `halt`.  Because KiGB and Goomba differ, stage 2 tests it so
that later tests relying on more precise timing can use `di halt`.

VBA is a clown show: with IME off, it can _call the handler anyway,_
and this causes it to enter a reset loop as the interrupt handler
lands on a `nop` slide into the test's loader.  Thus if `di halt` is
used, the handler must be initialized and prepared to run in case
VBA is in use.  I got _Libbet_ to boot in VBA by adding `reti` at
the STAT handler.

Beyond that, I don't fully understand `halt` in VBA.  I don't _want_
to fully understand `halt` in VBA.  I just want tests not to crash.

### Instruction timing

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

Blargg's test finishes in half a second on Game Boy, VBA-M, and mGBA.
It begins with an 11-cycle loop in `start_timer` ($C2D6) that tries
to synchronize to the 4-cycle phase by writing 0 to TIMA and reading
it 3 cycles later, trying again if it incremented.  On a Game Boy,
this succeeds within four tries.  On No$gmb, it always increments
and thus gets stuck, and the test has no timeout for this.

DIV in No$gmb counts _backwards,_ which would interfere with games'
random number generators.  This gives FF on No$gmb and 01 elsewhere:
```
INST 7E4F7E9128FC, HL=FF04
; disassembles to
ld a, [hl]  ; read DIV
ld c, a
.loop:
  ld a, [hl]
  sub c   ; If DIV has changed
  jr z, .loop
; C: original value; A: value difference
```

This exerciser locks TIMA in 64-cycle mode to the same phase as DIV.
Run this first:
```
INST E2AF22222200, AF 0700, BC 0007, HL FF04
; disassembles to
ldh [c], a
xor a
ld [hl+], a  ; reset DIV
ld [hl+], a  ; set TIMA value to 0
ld [hl+], a  ; set TIMA overflow reload to 0
```
Then run this repeatedly:
```
INST 0520FD2A1B46, BC 0100, HL FF04
; disassembles to
label:
dec b        ; wait 4*B cycles
jr nz, label
ld a, [hl+]  ; read DIV
inc de       ; burn a couple cycles
ld b, [hl]   ; read TIMA 4 cycles after DIV
```
A (DIV) and B (TIMA) should be the same on most presses, with B one
higher on a small fraction.  Everything but No$gmb gets this right.

Gnuboy is the first tested emulator to fail specific instructions
(in this case `34` and `37`) without crashing the entire test.

TODO: Ask gbdev #emudev which games depend on working timers

### Memory timing

Instructions that access memory other than the program stream
do so on the _last_ cycles of an instruction.  This includes read
instructions, write instructions, and read-modify-write instructions.

Blargg's memory access timing test synchronizes to a 64-cycle TIMA,
waits a variable amount of cycles, and executes each instruction with
TIMA as the address to determine on which cycle the access occurs.
Based on how TIMA reacts, it determines whether the access occurred
before or after the increment.

Because it relies on correct timers, which No$gmb lacks, a different
approach will be needed.

VBA-M fails `03-modify_timing` (01).  Gnuboy fails all three, though
it at least gets through enough of the tests to fail cleanly.

TODO: Ask gbdev #emudev which games depend most on working memory timing

### OAM bug

**Model-specific.**

The NES PPU's object attribute memory (OAM) controller is broken.
So is that of the monochrome Game Boy.  It copies one 8-byte pair of
entries over another pair if the program is not careful.  On the
Game Boy, the trigger is an increment or decrement operation on a
16-bit register pair (BC, DE, HL, or SP) while the pair's value is in
the range $FE00 to $FEFF during OAM scan (the first 80 dots of lines
0-143 while the LCD is on).  Affected instructions are `inc`, `dec`,
`push`, `pop`, and autoincrementing `ld`.  It _doesn't_ happen for
`ld hl, sp+`, `add sp`, or `add hl`, at any time other than OAM scan,
or on Game Boy Color in either mode.

My guess at the mechanism is that the incrementer puts the value on
the internal address bus without RD or WR, and the OAM controller
isn't equipped to ignore being decoded without RD or WR.

No$gmb and KiGB fail the LCD sync test for timing consistency, making
the other tests invalid.  Running the test in No$gmb's debugger shows
the emulator is incompatible with the method that Blargg's test uses
to synchronize to the start of frame at $C0BF.  LY advanced 109
debug clocks after the instruction that turns on the LCD, not 114 as
expected.  I also noticed that DIV changes greatly when LCD is turned
back on.  KiGB also fails, and it has no debugger to explain why.

VBA-M, mGBA, older Mesen, and older BGB all fail 2 (02), 4 (03),
5 (02), 7 (01), and 8 (02): everything but LCD sync and the
non-cause tests.

To write my own rough OAM bug test, I first needed to prove to myself
that the unused bits 3-0 of the attribute byte at $FE03+4n (palette,
flip, priority) exist as memory.  They don't on NES.  They do on DMG.
```
INST 774600000000, AF A500, HL FE03
; disassembles to
ld [hl], a
ld b, [hl]
```

My test performs the following steps:

1. Turn off the LCD, fill OAM, and read it back.  Fail on difference.
2. Turn on the LCD, wait a few scanlines, wait for mode 0, wait for
   mode 2, do a few 16-bit `inc` and `dec`, and turn off the LCD.
3. Read back OAM.  On GBC, fail on difference; otherwise fail on
   no difference.

No$gmb, KiGB, rew., Goomba, VBA, VBA-M, mGBA, Gambatte, and BizHawk
Gambatte all fail in Game Boy mode.  Among tested emulators, only
SameBoy and newer versions of bgb pass.

Numism original tests
---------------------
After I covered enough of Blargg's test space to thoroughly dunk on
No$gmb, VBA, and rew., I decided to branch out and cover aspects
not directly inspired by a Blargg test.

### Palettes

BGP, OBP0, and OBP1 ($FF47 through $FF49) map pixel values to shades
in DMG mode.  All 8 bits of all three registers are readable and
writable in all PPU modes, even though the PPU never uses bits 1-0
of OBP0 and OBP1.  (Ability of unused memory to hold values is like
DMG OAM and differs from the APU and NES OAM.)
```
INST 707E71000000, BC: 00E4, HL: FF47
; disassembles to
ld [hl], b  ; write value
ld a, [hl]  ; read it back
ld [hl], c  ; restore value
```
This turned out not usable as a test because no emulator fails it.

### Mode 3 duration

During each scanline, the PPU iterates through three different modes:
mode 2 (scanning OAM to find sprites overlapping that scanline),
mode 3 (rendering pixels), and mode 0 (horizontal blanking).
The duration of mode 3 varies based on how many overlapping sprites
the PPU found in mode 2.  Because video memory (VRAM) ignores writes
in mode 3, the programmer must write to VRAM outside mode 3.

To determine whether emulators accept or ignore writes properly,
I set out to time mode 3.  The STAT ($FF41) register can schedule
interrupt $48 at the start of mode 2, the start of mode 0 (horizontal
blanking interrupt or "hint"), or the start of mode 2 on a particular
scanline (LCD Y coordinate comparison or "LYC").  Because mode 2
always lasts 80 dots or 20 cycles, measuring modes 2 and 3 together
gives a duration for mode 3.

I chose to measure mode 3 with the stack red zone.  The exerciser
lets the user move sprites onto or off Y=64.  Then it schedules a
STAT interrupt for LYC, waits for it, schedules another for hint,
falls into a NOP slide, and reads from the red zone how many NOPs
were executed.  This works well in most emulators.

The exerciser lets the user move sprites onto or off the Y=64 line
and measures the time from 20 cycles after the start of
mode 2 on that line to the start of the following mode 0.

- High-tier emulators match the Game Boy exactly.  
  42 to 69 (Game Boy, SameBoy, bgb, Gambatte)
- Mid-tier emulators show some variance between 0 and 10 sprites.  
  42 to 67 (VBA-M), 42 to 57 (mGBA), 42 to 70 (Mesen)
- Low-tier emulators show constant duration.  
  42 (rew.), 47 (VBA), 48 (KiGB)
- Two emulators don't get the hint, not firing the second interrupt.  
  1 (No$gmb, Goomba)
- One emulator tested later didn't support STAT interrupts at all.  
  Hang at `halt` (Geebly as of commit 36519c7a37, 2021-01-31)

No$gmb interrupt behavior is deviously hard to characterize
because it has a [Heisenbug]: it differs based on whether
step debugging is active.

Say IF is $12, IE is $01, and I write $02 to IE.  In BGB, this write
immediately goes through, and I can see the step debugger jump into
the STAT handler.  In No$gmb, I see the effect of the STAT handler
when running normally.  If I put a breakpoint before the IE write and
step through it, the IE and IF in the I/O map change but the handler
doesn't get called.  Stepping by some amounts even corrupts the
initial SP and initial IEIF variables in the exerciser.
```
INST FB40000000E2, AF 0200, BC 00FF, IEIF 0112
; disassembles to
ei
ld b, b     ; source code breakpoint
nop
nop
nop
ldh [c], a  ; write to IF
```

[Heisenbug]: https://en.wikipedia.org/wiki/Heisenbug

### Clocking APU via DIV

The APU's sequencer controls the speed of sweep, envelope, and length
counter.  It receives a 512 Hz clock from DIV, implemented as a
falling edge detector on a DIV bit that stays low for 1024 M-cycles
and high for 1024 M-cycles.  I wrote a
coin that writes to DIV roughly every 660 cycles to keep DIV from
counting high enough to clock the APU's sequencer.
Low-tier emulators (VBA, Goomba, KiGB, rew., No$gmb) all fail.  It's
also my first coin that distinguishes VBA-M (fail) from mGBA (pass).

### Echo RAM

Echo RAM at $E000-$FDFF is a mirror of most of WRAM at $C000-$DDFF.
Some mappers incompletely decode SRAM at $A000 using A13, not A14.
On these cartridges, writes to echo RAM go to both WRAM and SRAM,
and reads from echo RAM produce a bus conflict as both memories
put different values on the data bus.  For this reason, Nintendo
required licensed games to avoid reading or writing echo RAM.
Yet in practice, it's safe on cartridges that completely
decode SRAM or lack SRAM entirely.

This exerciser shows that VBA 1.7 doesn't support echo RAM.
```
INST 70124E000000, AF 6900, BC A500, DE EFFF, HL CFFF
; disassembles to
ld [hl], b  ; Write to WRAM
ld [de], a  ; Overwrite WRAM via echo RAM
ld c, [hl]  ; Read WRAM
```
On a Game Boy, this gives C=69 (nice).  In BGB, it produces
`accessing echo RAM` and ends up with C=69.  VBA gives C=A5,
indicating that the WRAM write didn't take.

### JSGB breaks saving the stack pointer

In JSGB by Pedro Ladaria, `ld [abs], sp` behaves as if it were
`ld [abs], hl` due to a typo.  It required a modification to the
exerciser just to save the stack pointer when running the entered
instructions.  The compromise causes the exerciser to display wrong
values for AF and HL output.

Turn on `WITH_PLADARIA_JSGB_WORKAROUND` in inst.z80, rebuild the
exerciser, and run this
```
INST 08D0CF1A4700, DE CFD0, HL CF44, SP CFFC
; disassembles to
ld [$CFD0], sp
ld a, [de]
ld b, a
```
Gives B=FC on a Game Boy or B=44 in JSGB.

This is likely to break games using stack copy.  Because *Pokémon*
uses stack copy, I doubt I'll make a coin for this.

### Controller OR mask

On 2021-04-04, jvsTSX reported that this controller reading routine
works in bgb and does not work in VBA 1.7.
```
ld a, $10
ldh [rP1], a
; wait 6
ldh a, [rP1]
xor $DF
ld h, a
swap h

ld a, $20
ldh [rP1], a
; wait 6
ldh a, [rP1]
xor $EF
add h
```
The routine relies on the OR mask $C0 when reading `rP1` ($FF00).
Unlike SameBoy and VBA-M, VBA fails to apply this OR mask.
```
INST 77F5F17E74, AF 1000, HL FF00
; disassembles to
ld [hl], a  ; select buttons
push af     ; wait 7 cycles
pop af
ld a, [hl]  ; read input
ld [hl], h  ; release key matrix
```
Results

- In SameBoy and VisualBoyAdvance-M:  
  AF=1000 returns DF00 for A or DD00 for B+A; AF=2000 returns EF00
- In VisualBoyAdvance 1.7:  
  AF=1000 returns 1F00 for A or 1D00 for B+A; AF=2000 returns 2F00

The non-audio OR mask coin includes `rP1`.

Other tests
-----------
Things I can think off the top of my head to make exercisers for:

- Possibility of speeding up the APU sequencer by writing DIV at a
  period just longer than 1024 cycles
- DIV and TIMA sync at all TAC rates
- Values read and written to GBC palette ports in DMG and DMG-on-GBC,
  and DMG palette ports in GBC mode
- What is DMG Sound _trying_ to test, and what is No$gmb failing?
