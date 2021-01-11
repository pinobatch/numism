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
`branch_timing_tests`, `cpu_dummy_reads`, `cpu_interrupts_v2`, `instr_misc`, `instr_timing`, `ppu_tests`, `oam_read`, `oam_stress`, `ppu_open_bus`, `ppu_sprite_hit`, `ppu_sprite_overflow`, `ppu_vbl_nmi`, `sprite_hit_tests`, `sprite_overflow_tests`, `sprdma_and_dmc_dma`, `apu_test`, `blargg_apu`, `dmc_dma_during_read4.zip`, `square_timer_div2`, `test_apu_env`, `test_apu_sweep`, `test_apu_timers`, `test_tri_lin_ctr`

Not included:
- `cpu_reset`, `apu_reset`, `power_up_palette` incompatible with PowerPak
- `full_palette`, `nmi_sync`, `ntsc_torture`, and `apu_mixer` results are CPU-invisible
- `sprite_*_tests` is obsoleted by `ppu_sprite_*`
- Mapper-specific tests incompatible with the premise of being one game
- `cpu_timing_test6` has gone missing (404 Not Found)

[Emulator tests]: https://wiki.nesdev.com/w/index.php/Emulator_tests


