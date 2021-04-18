Daid's GB Emulator Shootout
===========================

For stages 3 and 4, I want to concentrate on four "decent" quality
emulators: Gambatte, bgb, mGBA, and VisualBoyAdvance-M.  To find
coins that test these, I'm relying on [GB Emulator Shootout] by Daid.
It shows the visual output of a couple hundred test ROMs in 11
emulators in a table, along with the number of tests that each
emulator passes.  Overall results as of April 2021:

- S tier (SameBoy, Emulicious, Beaten Dying Moon): 200 or higher
- Gambatte: 155
- bgb: 142
- mGBA: 133
- VisualBoyAdvance-M: 101
- Bottom tier (Goomba, VBA 1.7, and No$gmb): 48 or lower

The amount of difference between Gambatte and the S tier, between
VBA-M and Gambatte, and between Bottom tier and VBA-M are about the
same.  As mGBA is closer to Gambatte than to VBA-M, I place Gambatte,
bgb, and mGBA into B tier and VBA-M alone in M tier.

Thus I see a couple objectives for these stages:

- Tests that all B/M tier pass and most bottom tier fail
- Differences among B/M tier emulators

Scope of these stages
---------------------
Tests whose result the CPU cannot observe are out of scope.

- acid
- mooneye manual-only
- hacktix strikethrough

To promote the use of noninfringing replacements for Game Boy boot
ROM, I've declared a few register values at power up out of scope:
BC, DE, HL, DIV, and serial port clock.  In this way, I deliberately
depart from the reasoning of the _Pokémon_ speedrunning community
that currently maintains Gambatte.

- mooneye ​boot_div-dmgABCmgb
- mooneye ​boot_regs-dmgABC
- mooneye boot_sclk_align-dmgABCmgb
- mooneye ​boot_div-cgbABCDE
- mooneye ​boot_regs-cgb

Detailed tests of the MBC and RTC are also outside scope, as I intend
to present Numism as a game that runs on MBC1 or MBC5 without SRAM.
A counterpart to [Holy Mapperel] would be a more suitable venue.

- ax6 rtc*
- mooneye emulator_only

Tests that are meaningless on DMG shouldn't be included before
stage 4 in case I want to extend No$gmb results to stage 3.

- daid CGB ​speed_switch_timing_*
- samesuite APU tests that fewer than 2 B/M tier emulators pass
- samesuite dma

Tests where Gambatte, mGBA, bgb, and VBA-M differ
-------------------------------------------------
With the exception of mapper tests, visual-only tests, and Daid's
stop_instr, Gambatte passes all tests that one of mGBA, bgb, and
VBA-M fail.

VBA-M alone fails

- blargg interrupt_time (a 00 is missing on the third line)
- blargg mem_timing versions 1 and 2 modify timing (all res b, [hl] and set b, [hl])
- blargg DMG/CGB sound 09-wave_read_while_on (rumored that so does a GBA)
- blargg DMG sound ​11-regs_after_power (power off shouldn't affect NR41) and ​12-wave_write_while_on
- daid CGB stop_instr
- mooneye unused_hwio-GS ($FF02)
- mooneye ​di_timing-GS (round 2)
- mooneye oam_dma/sources-GS, oam_dma_restart, oam_dma_timing, stat_lyc_onoff
- mooneye intr_1_2_timing-GS
- ​mooneye rapid_di_ei (coin #22)
- mooneye tima_reload, tima_write_reloading, tma_write_reloading
- samesuite channel_3_wave_ram_locked_write

mGBA alone fails

- blargg DMG/CGB sound 07-len_sweep_period_sync (#5)
- blargg DMG sound ​11-regs_after_power (power off should clear NR41)
- blargg CGB sound 08-len_ctr_during_power and 10-wave_trigger_while_on
- mooneye rapid_toggle

mGBA and VBA-M fail

- blargg DMG sound 08-len_ctr_during_power and 10-wave_trigger_while_on
- blargg CGB sound ​12-wave (timer period or phase reset is wrong)
- daid DMG stop_instr
- mooneye ​boot_hwio-dmgABCmgb (may need to be tested on hardware while holding a button)
- mooneye hblank_ly_scx_timing-GS, intr_2_mode0_timing_sprites, lcdon_timing-GS, lcdon_write_timing-GS, vblank_stat_intr-GS
- samesuite channel_3_stop_delay

bgb and VBA-M fail

- mooneye add_sp_e_timing
- mooneye call_cc_timing, call_timing, jp_cc_timing, jp_timing,
  reti_timing, ret_cc_timing, ret_timing  (bgb: round 2; VBA-M: round 1)
- mooneye ie_push (bgb: unwanted cancel; VBA-M: not cancelled)
- mooneye ld_hl_sp_e_timing
- mooneye ​pop_timing

bgb, mGBA, and VBA-M fail

- mooneye oam_dma_start
- mooneye ​push_timing
- hacktix DMG/CGB bully

Tests where VBA-M beats bottom tier
-----------------------------------
Stages 1 and 2 already cover many misbehaviors that Blargg's tests
test, apart from some APU details that differ between DMG and CGB.

Some interesting cases where bgb, mGBA, and VBA-M pass and behaviors
among bottom tier differ should be investigated to see if they
duplicate an existing coin:

- mooneye ​reg_f: All B/M pass, VBA fails
- mooneye div_timing: Bottom tier emulators fail differently
- ​mooneye ei_timing: Only Goomba fails
- mooneye halt_ime0_nointr_timing: Bottom tier emulators fail differently
- mooneye halt_ime1_timing: Only KiGB fails
- mooneye halt_ime1_timing2-GS: Bottom tier emulators fail differently
- mooneye if_ie_registers: Goomba and KiGB fail
- mooneye daa: H flag stuff, like coin 15
- mooneye ​intr_timing: Goomba passes this one
- mooneye ​oam_dma/​reg_read: Only Goomba fails
- mooneye intr_2_0_timing: No$gmb passes this one
- mooneye intr_2_mode3_timing: No$gmb fails differently
- mooneye intr_2_oam_ok_timing
- mooneye stat_irq_blocking: Bottom tier emulators fail differently
- mooneye reti_intr_timing: Only Goomba fails
- mooneye ​ret*_timing: No$gmb shows logo, Goomba shows blank screen
- mooneye div_write
- ​mooneye tim00: Goomba passes
- mooneye tim00_div_trigger: VBA passes
- mooneye ​tim01: VBA passes
- mooneye tim01_div_trigger
- mooneye ​tim10, tim10_div_trigger, ​tim11, tim11_div_trigger:
  Bottom tier emulators fail differently
- samesuite blocking_bgpi_increase: Goomba and VBA fail

[GB Emulator Shootout]: https://daid.github.io/GBEmulatorShootout/
[Holy Mapperel]: https://github.com/pinobatch/holy-mapperel/
