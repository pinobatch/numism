NES emulator testing
====================

Emulators under test
--------------------
When starting out, I'd like the emulators to be evenly spaced on the
accuracy front.

First I plan to test Mesen, FCEUX, no$nes, and PocketNES.
Other emulators I'd like to test include
NESticle, loopyNES, NESten, rew., RockNES, and PuNES.

PocketNES v7a and later require an extended 48-byte header before
the iNES header.  ROM builders are expected to follow this format
described in the [PocketNES FAQ].

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
`dmc_dma_during_read4.zip`, `square_timer_div2`, `test_apu_env`,
`test_apu_sweep`, `test_apu_timers`, `test_tri_lin_ctr`

Not included:
- `cpu_reset`, `apu_reset`, `power_up_palette` incompatible with
  PowerPak
- `full_palette`, `nmi_sync`, `ntsc_torture`, and `apu_mixer` results
  are CPU-invisible
- `sprite_*_tests` is obsoleted by `ppu_sprite_*`
- Mapper-specific tests incompatible with Numism's premise of being
  one game on a period-spec board
- `cpu_timing_test6` has gone missing (404 Not Found)

[Emulator tests]: https://wiki.nesdev.com/w/index.php/Emulator_tests

### APU

APU Test (`apu_test`)

* Mesen: 8/8
* PocketNES: 5/8  
  Failed 5-len_timing (#2), 6-irq_flag_timing (#4), 7-dmc_basics (#19)
* FCEUX: 3/8
  Failed 3-irq_flag (#6), 4-jitter (#2), 5-len_timing (#2),
  6-irq_flag_timing (#2), 7-dmc_basics (#8)
* No$nes: 0/8
  Failed 1 through 7; froze on 8

APU Length Counter (`blargg_apu_2005.07.30`)

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
  `dma_2007_read` gives `498C5C5F` (differs from Mesen)  
  `double_2007_read` gives `D84F6815`
* PocketNES: Passed 1; failed `dma_4016_read` and `read_write_2007`  
  `dma_2007_read` gives `498C5C5F` (same as FCEUX)  
  `double_2007_read` gives `F018C287` (same as Mesen)

### PPU

`blargg_ppu_tests_2005.09.15b` contains `palette_ram`, `sprite_ram`,
`vbl_clear_time`, and `vram_access`.  I'm excluding an additional
test for the power-up palette whose result is not repeatable.

- Mesen, FCEUX, and PocketNES score 4/4.
- No$nes scores 3/4, failing `vbl_clear_time` ($03).

### CPU

`branch_timing_tests` contains `1.Branch_Basics`,
`2.Backward_Branch`, and `3.Forward_Branch`.  Each depends on
the preceding tests.  Mesen, No$nes, and PocketNES score 3/3,
whereas FCEUX fails `1.Branch_Basics` (#2: NMI period too short).

`cpu_dummy_reads`

* Mesen: Pass
* FCEUX: No$nes, PocketNES: Error 3 (LDA abs,x)

`cpu_interrupts_v2`

* Mesen: 5/5
* FCEUX: 1/5  
  Fails `2-nmi_and_brk`, `3-nmi_and_irq`, `4-irq_and_dma`, and `5-branch_delays_irq`
* PocketNES: 0/5
* No$nes: 0/4, then `5-branch_delays_irq` _hangs_ during the first test.

`instr_timing`

* Mesen: 2/2
* FCEUX: 1/2. Instructions E2 and BB have the wrong cycle counts.
  `branch_timing` passed.
* PocketNES: 0/2.  The tests report many instructions as taking 0
  cycles, which I'm attributing to speed hacks that allow games to
  run on a sub-20 MHz CPU.
* No$nes: `1-instr_timing` doesn't write "Official instructions", and
  `2-branch_timing` doesn't write anything.

### Remaining tests

These tests have yet to be run on the first four NES emulators:

`nes_instr_misc`, `oam_read`, `oam_stress`, `ppu_open_bus`, 
`ppu_sprite_hit`, `ppu_sprite_overflow`, `ppu_vbl_nmi`, 
`sprdma_and_dmc_dma`, `square_timer_div2`, `test_apu_env`, 
`test_apu_sweep`, `test_apu_timers`, `test_tri_lin_ctr`
