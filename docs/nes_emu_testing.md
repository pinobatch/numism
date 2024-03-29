NES emulator testing
====================

I'm testing several current and historic emulators of the Nintendo
Entertainment System to compare and contrast their behavior with
that of an authentic NES.  I seek to produce "coins," my term for
short test programs to highlight a behavior difference.
(See [What makes a good coin?] and [NES coin list].)

[What makes a good coin?]: ./good_coin.md
[NES coin list]: ./nes_coins.md

Emulators under test
--------------------
I'm operating under the principle of "no cash."  This means no paid
operating systems nor paid emulators.  Thus I'm running tests on
Ubuntu, a GNU/Linux distribution.  I test emulators made for Windows
in Wine 5.0.2.  I've excluded 3dSen due to its paywall, and I've
excluded RockNES 5.65 because [RockNES ignores all input] under Wine.

When starting out, I'd like the emulators to be evenly spaced on the
accuracy front.

I regularly test in Mesen (Sour final), FCEUX 2.3.0 (New PPU),
No$nes 1.2, and PocketNES 2013-07-01.  Occasionally I'll run
something in loopyNES 11/21/99, NESticle x.xx, NESten 0.61 beta 1,
Nintendulator 0.985, and rew. 12STX. Other emulators I'd like to test
include puNES, NESHawk, and iNES.

Unlike No$gmb, No$nes takes a ROM path on the command line.
It must be an absolute path with backslashes.  Save this as
`~/.local/bin/nones`, edit it to correspond to the path on your
system, and make it executable (`chmod +x ~/.local/bin/nones`).
```
#!/bin/sh
wine '/path/to/NO$NES.EXE' $(winepath -w $1)
```

[NESten] is provided as an installer built with Nullsoft PIMP, the
predecessor of NSIS.  Version 0.61 beta 1 was the last release before
its mapper API was repurposed for Nintendulator.  It likewise needs
an absolute path.  Here's `~/.local/bin/nesten`, set up for the
installation path that the installer suggests:
```
#!/bin/sh
wine $HOME/'.wine/drive_c/NESten/NESten.exe' `winepath -w "$1"`
```

Nintendulator understands relative paths, including those using
forward slashes.  Here's `~/.local/bin/nulator`:
```
#!/bin/sh
wine '/path/to/Nintendulator.exe' "$1"
```

As with Mesen-S, Mesen is run in Mono 6.10 to avoid a regression that
breaks preferences dialogs.

[loopyNES] and [NESticle] are run in DOSBox 0.74-3.  NESticle needs a
DOS extender; we use [DOS/32A] to replace DOS/4GW.
Here's `~/.local/bin/lnes`:
```
#!/bin/sh
set -e
cp "$1" /path/to/loopytmp.nes
cd /path/to
echo 'loopynes.exe loopytmp.nes' > loopytmp.bat
dosbox loopytmp.bat
rm loopytmp.nes loopytmp.bat; true
```

And `~/.local/bin/nestc`:
```
#!/bin/sh
set -e
cp "$1" /path/to/nestctmp.nes
cd /path/to
echo 'dos32a NESTICLE.EXE nestctmp.nes' > nestctmp.bat
dosbox nestctmp.bat
rm nestctmp.nes nestctmp.bat; true
```

Change NESticle timing to hblank cycles 114, frame lines 240, vblank
lines 22, and virtual fps 60.	

Once you click the DOSBox window, such as to operate NESticle's GUI,
you'll need to press Ctrl+F10 to move the mouse out of the window.

PocketNES began as a Game Boy Advance port of loopyNES.  PocketNES
v7a and later require an extended 48-byte header before the iNES
header.  ROM builders are expected to follow this format described
in the [PocketNES FAQ], for which I wrote [my own builder] in Python.

- 32 bytes: ROM title (NUL terminated)
- 4 bytes: ROM size (iNES header + PRG ROM + CHR ROM)
- 4 bytes: Emulation settings
    - Bit 0: Enable PPU speed hack
    - Bit 1: Disable CPU speed hack
    - Bit 2: Use approximate PAL NES timing
    - Bit 5: Y follow type (0: sprite number; 1: CPU address)
- 4 bytes: Y follow value
- 4 bytes: Reserved (set to 0)
- 16 bytes: iNES header
- 16384*p bytes: PRG ROM
- 8192*c bytes: CHR ROM

Here's `~/.local/bin/pnes` that calls the builder:
```
#!/bin/sh
set -e
/path/to/numism/nes/tools/pnesbuild.py /path/to/pocketnes.gba "$1" -o "$1.gba"
mgba-qt "$1.gba"
```

[RockNES ignores all input]: https://forums.nesdev.com/viewtopic.php?p=269315#p269315
[NESten]: https://tnse.zophar.net/NESten.htm
[loopyNES]: https://3dscapture.com/NES/
[NESticle]: https://www.zophar.net/dos/nes/nesticle.html
[DOS/32A]: https://dos32a.narechk.net/
[PocketNES FAQ]: https://web.archive.org/web/20131102194638/http://pocketnes.org/faq.html
[my own builder]: ../nes/tools/pnesbuild.py

Blargg's tests
--------------
As with Game Boy emulators, I have begun to evaluate Nintendo
Entertainment System (NES) emulators using tests by Blargg.
These are listed at "[Emulator tests]" on NESdev Wiki:  
`branch_timing_tests`, `cpu_dummy_reads`, `cpu_interrupts_v2`,
`instr_misc`, `instr_timing`, `ppu_tests`, `oam_read`, `oam_stress`,
`ppu_open_bus`, `ppu_sprite_hit`, `ppu_sprite_overflow`,
`ppu_vbl_nmi`, `sprite_hit_tests`, `sprite_overflow_tests`,
`sprdma_and_dmc_dma`, `apu_test`, `blargg_apu`,
`dmc_dma_during_read4`

Not included:

- `cpu_reset`, `apu_reset`, `power_up_palette` incompatible with
  PowerPak
- `full_palette`, `nmi_sync`, `ntsc_torture`, `apu_mixer`,
  `square_timer_div2`, `test_apu_env`, `test_apu_sweep`,
  `test_apu_timers`, and `test_tri_lin_ctr` results are CPU-invisible
- `sprite_*_tests` is obsoleted by `ppu_sprite_*`
- Mapper-specific tests incompatible with Numism's premise of being
  one game on a period-spec board
- `cpu_timing_test6` has gone missing (404 Not Found)

Overall results show PocketNES slightly edging out FCEUX.

- Mesen: CPU 15/15, APU 24/24, PPU 32/32
- Nintendulator: CPU 13/15, APU 22/24, PPU 28/32
- PocketNES: CPU 4/15, APU 11/24, PPU 21/32
- FCEUX: CPU 5/15, APU 8/24, PPU 20/32
- No$nes: CPU 4/15, APU 0/24, PPU 12/32
- NESten: CPU 5/15, APU 1/24, PPU 5/32
- loopyNES: CPU 1/15, APU 1/24, PPU 8/32
- rew.: CPU 2/15, APU 0/24, PPU 3/32
- NESticle: CPU 1/15, APU 0/24, PPU 2/32

[Emulator tests]: https://wiki.nesdev.com/w/index.php/Emulator_tests

### CPU

Many interrupt tests fail on No$nes because the emulator doesn't
implement the APU frame IRQ.

`branch_timing_tests` contains `1.Branch_Basics`,
`2.Backward_Branch`, and `3.Forward_Branch`.  Each depends on
the preceding tests.

* Pass: Mesen, Nintendulator, No$nes, NESten, and PocketNES
* FCEUX and loopyNES: 0/3  
  Failed `1.Branch_Basics` (#2: NMI period too short)
* NESticle and rew.: 0/3  
  Failed `1.Branch_Basics` (#3: NMI period too long)

`cpu_dummy_reads`

* Pass: Mesen, Nintendulator
* Fail: FCEUX, No$nes, loopyNES, PocketNES, rew. (all #3: LDA abs,x);
  NESticle and NESten (#2: $2002 not mirrored)
* Source code not included in zip; cpow's repo has [cpu_dummy_reads.s]

Though I don't have an NES exerciser yet, and I estimate that
instructions under test will be less dense than on Game Boy,
I can offer conjectures to be tested when I do build an exerciser.
No$nes fails to perform the dummy read with $2002 then $2102:
```
jsr wait_vbl_no_ack
ldx #$22
lda $20E0,x  ; read $2002 then $2102 twice, first D7=1 then D7=0
bmi @test_failed
```
FCEUX fails to perform the dummy read with $3F02 then $4002:
```
jsr wait_vbl_no_ack
ldx #$22
lda $3FE0,x  ; read $3F02 then $4002, once with D7=1 once open bus
lda $2002    ; Second read D7=0
bpl @test_failed
```
A test for this must take care not to assume facts not in evidence,
such as NESticle's failure to acknowledge NMI at $2002.

`cpu_interrupts_v2`

* Mesen: 5/5
* Nintendulator: 4/5  
  Failed `4-irq_and_dma` (D8F25536)
* FCEUX: 1/5  
  Failed `2-nmi_and_brk`, `3-nmi_and_irq`, `4-irq_and_dma`, and
  `5-branch_delays_irq`
* PocketNES: 0/5
* No$nes, NESten, rew., loopyNES, NESticle: 0/4  
  `5-branch_delays_irq` _hangs_ during the first test.

`instr_timing`

* Mesen: 2/2
* FCEUX: 1/2  
  `1-instr_timing`: Unofficial instructions E2 (`nop #imm`) and
  BB (`las abs,y`) have wrong cycle counts
* Nintendulator: 1/2
  `1-instr_timing`: Unofficial instructions 8B (`xaa #imm`),
  93   (`ahx (zp),y`), 9B (`tas abs,y`), 9F, (`ahx a,y`), and
  BB (`las abs,y`) have wrong cycle counts
* PocketNES: 0/2  
  The tests report many instructions as taking 0 cycles, which I
  attribute to speed hacks that let games run on a sub-20 MHz CPU.
* NESten: 0/2  
  A bunch of 0 and 7 counts where there shouldn't have been
* loopyNES, NESticle: 0/2  
  Both fail `1-instr_timing` (#5)
* rew.: 0/1  
  `1-instr_timing` has no output.
* No$nes: `1-instr_timing` doesn't write "Official instructions", and
  `2-branch_timing` has no output.

`nes_instr_misc`

* Mesen, Nintendulator: 4/4
* FCEUX: 3/4  
  Failed `03-dummy_reads` (#3)
* rew.: 2/4  
  Failed `03-dummy_reads`(#3), `04-dummy_reads_apu` (#2)
* NESten: 2/4  
  Failed `03-dummy_reads`(#2), `04-dummy_reads_apu` (#2)
* No$nes, loopyNES, and PocketNES: 1/4  
  Failed `02-branch_wrap` (#2), `03-dummy_reads` (#3),
  `04-dummy_reads_apu` (#2)
* NESticle: 1/3  
  Failed `03-dummy_reads` (#2), `04-dummy_reads_apu` (#2)  
  `02-branch_wrap` hangs

Like the No$gmb debugger, the No$nes debugger has a [heisenbug]
(behavior difference arising while a behavior is under test).
If I run `02-branch_wrap.nes` normally, it fails.  If I set a
breakpoint at $E820 (the start of the body of the test) and step
through the branches around $FFFF and $0000, the test passes.
This debugger is worth no cash.

(Further testing showed that a forward branch in No$nes overshoots
by 2 bytes in some circumstances.)

Both PocketNES and No$nes turned out to misbehave on branches from
$BFFx to $C00x as well.

[Heisenbug]: https://en.wikipedia.org/wiki/Heisenbug

### APU

It has been suggested that some of `apu_test` and
`blargg_apu_2005.07.30` may be duplicative, causing undue weight.

`apu_test`

* Mesen, Nintendulator: 8/8
* PocketNES: 5/8  
  Failed `5-len_timing` (#2), `6-irq_flag_timing` (#4),
  `7-dmc_basics` (#19)
* FCEUX: 3/8  
  Failed `3-irq_flag` (#6), `4-jitter` (#2), `5-len_timing` (#2),
  `6-irq_flag_timing` (#2), `7-dmc_basics` (#8)
* NESten: 0/8  
  Failed #3, Failed, Failed #4, Failed #3, Failed #3, Failed #3,
  Failed #2, Failed #3
* loopyNES: 0/8  
  Failed #2, Failed, Failed #4, Failed #3, Failed #5, Failed #3,
  Failed #2, Failed #2
* NESticle: 0/8  
  Failed #2, Failed, Failed #4, Failed #4, Failed #2, Failed #2,
  Failed #2, Failed #2
* rew., No$nes: 0/8  
  Failed 1 through 7; 8 hung

`blargg_apu_2005.07.30` tests the length counter

* Mesen, Nintendulator: 11/11
* PocketNES: 5/11  
  $01, $01, $01, $01, $02, $02, $04, $02, $04, $01, $05
* FCEUX: 3/11  
  $01, $01, $06, $02, $02, $02, $02, $02, $03, $01, $05
* NESten: 0/11
  $04, $F8 $FF $1E $02, $04, $03, $03, $03, $03, $04, $04, $04, $02
* No$nes: 0/11  
  $03, $F8 $FF $1E $02, $02, $02, $03, $03, $02, $04, $02, $03, $02
* loopyNES and NESticle: 0/11  
  $02, $F8 $00 $1E $02, $04, $03, $02, $02, $03, $04, $04, $02, $02
* rew.: 0/11  
  $02, $F8 $00 $1E $02, $02, $02, $02, $02, $02, $03, $02, $02, $02

Things low-tier emulators get wrong: length counter table and
changing between with and without length counter.

`dmc_dma_during_read4` contains five tests.  Three have a pass or
fail condition; the others give only a CRC32 value.  Will need to
validate the CRC against my NES.

* Mesen: 3/3  
  `dma_2007_read` gives `159A7A8F`  
  `double_2007_read` gives `F018C287`
* Nintendulator: 3/3  
  `dma_2007_read` gives `5E3DF9C4`  
  `double_2007_read` gives `D84F6815`
* FCEUX: 2/3; failed `dma_4016_read`  
  `dma_2007_read` gives `498C5C5F`  
  `double_2007_read` gives `D84F6815` (same as Nintendulator)
* loopyNES, PocketNES, and NESten: 1/3; failed `dma_4016_read`
  and `read_write_2007`  
  `dma_2007_read` gives `498C5C5F` (same as FCEUX)  
  `double_2007_read` gives `F018C287` (same as Mesen)
* NESticle: 0/3; failed `read_write_2007` and `dma_2007_write`  
  `dma_2007_read` gives `498C5C5F` (same as FCEUX)  
  `double_2007_read` gives `B8364881`  
  `dma_4016_read` hung on a black screen
* No$nes and rew.: 0/3; failed `read_write_2007`  
  `double_2007_read` gives `F018C287` (same as Mesen); `dma_*` hung
  on a black screen

`sprdma_and_dmc_dma` (2 variants)

* Pass: Mesen
* Fail: PocketNES (343E3215), FCEUX (0708B479/A6AB180A),
  NESten (93A657B9/4D2212F3), Nintendulator (DCE73FC5/542FC3AE)
* Hang: No$nes, loopyNES, NESticle, and rew. (black screen)

### PPU

`blargg_ppu_tests_2005.09.15b` contains `palette_ram`, `sprite_ram`,
`vbl_clear_time`, `vram_access`, and a fifth test for the power-up
palette.  I'm excluding the last, whose result is not repeatable.

- Mesen, FCEUX, Nintendulator, and PocketNES: 4/4
- No$nes: 3/4  
  Failed `vbl_clear_time` ($03)
- NESten: 1/4  
  Failed `palette_ram` ($03), `sprite_ram` ($02),
  and `vbl_clear_time` ($02)
- loopyNES: 1/4  
  Failed `sprite_ram` ($07), `vbl_clear_time` ($03),
  and `vram_access` ($06)
- rew.: 0/4  
  Failed `palette_ram` ($02), `sprite_ram` ($04),
  `vbl_clear_time` ($03), and `vram_access` ($06)
- NESticle: 0/4
  Failed `palette_ram` ($02), `sprite_ram` ($04),
  `vbl_clear_time` ($02), and `vram_access` ($04)

`oam_read`

NESten was the fifth emulator tested and the first to fail,
causing me to have to stop excluding this test as a gimme.

- Pass: FCEUX, Mesen, No$nes, PocketNES, rew., Nintendulator,
  loopyNES, and NESticle
- Fail: NESten (FEF6F55C)

`oam_stress`

This takes a while to complete and can fail even on hardware
because it doesn't account for odd modes (phase alignment
between CPU and PPU clock).  Don't stress about failing it.

* Pass: Mesen, Nintendulator
* Fail (B0A94719): FCEUX, No$nes, PocketNES
* Fail (5FBA8510): NESten
* Fail (59916E5B): rew., loopyNES, NESticle

`ppu_open_bus`

Tests the data retention of the PPU's CPU interface data bus, which
emulators refer to as `io_db` or `PPUGenLatch`.

* Pass: Mesen, No$nes
* Fail (#3 no decay): FCEUX, NESten, Nintendulator
* Fail (#2 no support at all): PocketNES, rew., loopyNES, NESticle

`ppu_sprite_hit`

* Mesen: 10/10
* Nintendulator: 8/10  
  Failed `09-timing` (#3), `10-timing_order` (#5)
* FCEUX: 8/10  
  Failed `09-timing` (#4), `10-timing_order` (#2)
* PocketNES: 8/10  
  Failed `09-timing` (#10), `10-timing_order` (#6)
* loopyNES: 7/10
  Failed `05-left_clip` (#2), `09-timing` (#2), `10-timing_order` (#2)
* No$nes: 4/10  
  Failed `04-flip` (#3), `05-left_clip` (#2), `06-right_edge` (#2),
  `07-screen_bottom` (#4), `09-timing` (#2), `10-timing_order` (#2)
* NESten: 3/10  
  Failed `01-basics` (#4), `02-alignment` (#3), `05-left_clip` (#2),
  `06-right_edge` (#2), `08-double_height` (#2), `09-timing` (#2),
  `10-timing_order` (#2)
* rew. and NESticle: 2/10  
  Failed `01-basics` (#4), `02-alignment` (#3), `05-left_clip` (#2),
  `06-right_edge` (#2), `07-screen_bottom` (#3), `08-double_height`
  (#2), `09-timing` (#2), `10-timing_order` (#2)

`ppu_sprite_overflow`

* Mesen, Nintendulator: 5/5
* FCEUX: 3/5  
  Failed `03-timing` (#3), `04-obscure` (#2)
* No$nes: 2/5  
  Failed `03-timing` (#3), `04-obscure` (#2), `05-emulator` (#3)
* NESten: 0/5  
  Failed `01-basics` (#7), `02-details` (#5), `03-timing` (#3),
  `04-obscure` (#7), `05-emulator` (#3)
* PocketNES, loopyNES, rew., NESticle: 0/5  
  Failed `01-basics` (#2), making the rest untestable?

`ppu_vbl_nmi`

* Mesen: 10/10
* Nintendulator: 9/10
  Failed `07-nmi_on_timing` (2B1F5269)
* PocketNES: 8/10  
  Failed `07-nmi_on_timing` (2B1F5269), `10-even_odd_timing` (#2)
* FCEUX: 4/10  
  Failed `02-vbl_set_time` (4103C340), `05-nmi_timing` (7A959B66),
  `06-suppression` (3FE15516), `07-nmi_on_timing` (2B1F5269),
  `08-nmi_off_timing` (FA8C430B), `10-even_odd_timing` (#3)
* NESten: 1/10   
  Failed `02-vbl_set_time` (4103C340), `03-vbl_clear_time`
  (F9DC4B60), `04-nmi_control` (#3), `05-nmi_timing` (318E0281),
  `06-suppression` (3574DB97), `07-nmi_on_timing` (FD9CDCC9),
  `08-nmi_off_timing` (FA8C430B), `09_even_odd_frames` (#2),
  `10-even_odd_timing` (#2)
* No$nes: 1/10  
  Failed `01-vbl_basics` (#7), `02-vbl_set_time` (C2633058),
  `03-vbl_clear_time` (74346C62), `05-nmi_timing` (67847679),
  `06-suppression` (636EA6C0), `07-nmi_on_timing` (F4AFB970),
  `08-nmi_off_timing` (6CB785AD), `09_even_odd_frames` (#2),
  `10-even_odd_timing` (#2)
* loopyNES: 0/10  
  Failed `01-vbl_basics` (#7), `02-vbl_set_time` (D5AE32A3),
  `03-vbl_clear_time` (FD9CDCC9), `04-nmi_control` (#11),
  `05-nmi_timing` (31757776), `06-suppression` (0900EB39),
  `07-nmi_on_timing` (FD9CDCC9), `08-nmi_off_timing` (A46D9938),
  `09_even_odd_frames` (#2), `10-even_odd_timing` (#2)
* NESticle: 0/10  
  Failed `01-vbl_basics` (#3), `02-vbl_set_time` (AAACAA4D),
  `03-vbl_clear_time` (hash offscreen), `04-nmi_control` (#3),
  `05-nmi_timing` (31850281), `06-suppression` (hash offscreen),
  `07-nmi_on_timing` (hash offscreen),
  `08-nmi_off_timing` (?08C430B, partly offscreen),
  `09_even_odd_frames` (#2), `10-even_odd_timing` (#2)
* rew.: 0/8  
  Failed `01-vbl_basics` (#4), `02-vbl_set_time` (04A52CE1),
  `03-vbl_clear_time` (F9DC4B60), `04-nmi_control` (#5),
  `05-nmi_timing` (318E0281), `06-suppression` (FED37AAD),
  `07-nmi_on_timing` (FD9CDCC9), `08-nmi_off_timing` (FA8C430B)  
  Hangs on `09_even_odd_frames` and `10-even_odd_timing`

`01-vbl_basics` (#3: Reading VBL flag should clear it) is what I've
called "the NESticle bug" since roughly 2000 or so when I was active
on Everything2.
