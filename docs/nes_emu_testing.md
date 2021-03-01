NES emulator testing
====================

Emulators under test
--------------------
When starting out, I'd like the emulators to be evenly spaced on the
accuracy front.

I've tested Mesen (Sour final), FCEUX 2.3.0 (New PPU), No$nes 1.2,
and PocketNES 2013-07-01.  Other emulators I'd like to test include
NESticle, loopyNES, NESten, rew., RockNES, and puNES.

PocketNES v7a and later require an extended 48-byte header before
the iNES header.  ROM builders are expected to follow this format
described in the [PocketNES FAQ], for which I wrote [my own builder].

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
`dmc_dma_during_read4.zip`

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

- Mesen: CPU 15/15, APU 24/24, PPU 31/31
- PocketNES: CPU 4/15, APU 11/24, PPU 20/31
- FCEUX: CPU 5/15, APU 8/24, PPU 19/31
- No$nes: CPU 4/15, APU 0/24, PPU 11/24

[Emulator tests]: https://wiki.nesdev.com/w/index.php/Emulator_tests

### CPU

`branch_timing_tests` contains `1.Branch_Basics`,
`2.Backward_Branch`, and `3.Forward_Branch`.  Each depends on
the preceding tests.

* Pass: Mesen, No$nes, and PocketNES
* Fail: FCEUX at `1.Branch_Basics` (#2: NMI period too short)

`cpu_dummy_reads`

* Pass: Mesen
* Fail: FCEUX, No$nes, PocketNES (all #3: LDA abs,x)
* Source code not included in zip; cpow's repo has [cpu_dummy_reads.s]

Though I don't have an NES exerciser yet, and I estimate that
instructions under test will be less dense than on Game Boy,
I can offer conjectures to be tested when I do build an exerciser.
No$nes fails to perform the dummy read with $2102 then $2002:
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
* FCEUX: 1/5  
  Fails `2-nmi_and_brk`, `3-nmi_and_irq`, `4-irq_and_dma`, and
  `5-branch_delays_irq`
* PocketNES: 0/5
* No$nes: 0/4  
  `5-branch_delays_irq` _hangs_ during the first test.

`instr_timing`

* Mesen: 2/2
* FCEUX: 1/2  
  `1-instr_timing`: Instructions E2 and BB have wrong cycle counts
* PocketNES: 0/2  
  The tests report many instructions as taking 0 cycles, which I
  attribute to speed hacks that let games run on a sub-20 MHz CPU.
* No$nes: `1-instr_timing` doesn't write "Official instructions", and
  `2-branch_timing` doesn't write anything.

`nes_instr_misc`

* Mesen: 4/4
* FCEUX: 3/4  
  Failed `03-dummy_reads` (#3)
* No$nes and PocketNES: 1/4  
  Failed `02-branch_wrap` (#2), `03-dummy_reads` (#3),
  `04-dummy_reads_apu` (#2)

Like the No$gmb debugger, the No$nes debugger has a [heisenbug]
(behavior difference arising while a behavior is under test).
If I run `02-branch_wrap.nes` normally, it fails.  If I set a
breakpoint at $E820 (the start of the body of the test) and step
through the branches around $FF and $01, the test passes.
This debugger is worth no cash.

[Heisenbug]: https://en.wikipedia.org/wiki/Heisenbug

### APU

`apu_test`

* Mesen: 8/8
* PocketNES: 5/8  
  Failed `5-len_timing` (#2), `6-irq_flag_timing` (#4),
  `7-dmc_basics` (#19)
* FCEUX: 3/8  
  Failed `3-irq_flag` (#6), `4-jitter` (#2), `5-len_timing` (#2),
  `6-irq_flag_timing` (#2), `7-dmc_basics` (#8)
* No$nes: 0/8  
  Failed 1 through 7; 8 hung

`blargg_apu_2005.07.30` tests the length counter

* Mesen: 11/11
* PocketNES: 5/11  
  $01, $01, $01, $01, $02, $02, $04, $02, $04, $01, $05
* FCEUX: 3/11  
  $01, $01, $06, $02, $02, $02, $02, $02, $03, $01, $05
* No$nes: 0/11  
  $03, $F8 $FF $1E $02, $02, $02, $03, $03, $02, $04, $02, $03, $02

Things only no$nes gets wrong: length counter table and changing
between with and without length counter.

`dmc_dma_during_read4` contains five tests.  Three have a pass or
fail condition; the others give only a CRC32 value.  Will need to
validate the CRC against my NES.

* Mesen: Passed 3  
  `dma_2007_read` gives `159A7A8F`  
  `double_2007_read` gives `F018C287`
* FCEUX: Passed 2; failed `dma_4016_read`  
  `dma_2007_read` gives `498C5C5F`  
  `double_2007_read` gives `D84F6815`
* PocketNES: Passed 1; failed `dma_4016_read` and `read_write_2007`  
  `dma_2007_read` gives `498C5C5F` (same as FCEUX)  
  `double_2007_read` gives `F018C287` (same as Mesen)
* No$nes: Passed 0; failed `read_write_2007`  
  `double_2007_read` gives `F018C287` (same as Mesen); `dma_*` hung
  on a black screen

`sprdma_and_dmc_dma` (2 variants)

* Pass: Mesen
* Fail: PocketNES (343E3215), FCEUX (0708B479/A6AB180A)
* Hang: No$nes (black screen)

### PPU

`blargg_ppu_tests_2005.09.15b` contains `palette_ram`, `sprite_ram`,
`vbl_clear_time`, `vram_access`, and a fifth test for the power-up
palette.  I'm excluding the last, whose result is not repeatable.

- Pass: Mesen, FCEUX, and PocketNES
- Fail: No$nes 3/4, failing `vbl_clear_time` ($03).

`oam_read`

No points, as FCEUX, Mesen, No$nes, and PocketNES all pass.

`oam_stress` takes a while to complete, and it often fails even on
hardware because it doesn't account for odd modes (phase alignment
between CPU and PPU clock).  Don't stress about failing it.

* Pass: Mesen
* Fail: FCEUX (B0A94719), No$nes (B0A94719), PocketNES (B0A94719)

`ppu_open_bus`

* Pass: Mesen, No$nes
* Fail: PocketNES (#2), FCEUX (#3)

`ppu_sprite_hit`

* Mesen: 10/10
* FCEUX: 8/10  
  Failed `09-timing` (#4), `10-timing_order` (#2)
* PocketNES: 8/10  
  Failed `09-timing` (#10), `10-timing_order` (#6)
* No$nes: 4/10  
  Failed `04-flip` (#3), `05-left_clip` (#2), `06-right_edge` (#2),
  `07-screen_bottom` (#4), `09-timing` (#2), `10-timing_order` (#2)

`ppu_sprite_overflow`

* Mesen: 5/5
* FCEUX: 3/5  
  Failed `03-timing` (#3), `04-obscure` (#2)
* No$nes: 2/5  
  Failed `03-timing` (#3), `04-obscure` (#2), `05-emulator` (#3)
* PocketNES: 0/5  
  Failed `01-basics` (#2), making the rest untestable?

`ppu_vbl_nmi`

* Mesen: 10/10
* PocketNES: 8/10  
  Failed: `07-nmi_on_timing` (2B1F5269), `10-even_odd_timing` (#2)
* FCEUX: 4/10  
  Failed: `02-vbl_set_time` (4103C340), `05-nmi_timing` (7A959B66),
  `06-suppression` (3FE15516), `07-nmi_on_timing` (2B1F5269),
  `08-nmi_off_timing` (FA8C430B), `10-even_odd_timing` (#3)
* No$nes: 1/10  
  Failed: `01-vbl_basics` (#7), `02-vbl_set_time` (C2633058),
  `03-vbl_clear_time` (74346C62), `05-nmi_timing` (67847679),
  `06-suppression` (636EA6C0), `07-nmi_on_timing` (F4AFB970),
  `08-nmi_off_timing` (6CB785AD), `09_even_odd_frames` (#2),
  `10-even_odd_timing` (#2)

