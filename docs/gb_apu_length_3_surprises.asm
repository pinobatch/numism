; Three surprising behaviors of Game Boy APU length counters
; By Damian Yerrick, 2023-05-10
; No rights reserved.  Anyone is free to copy, modify, publish, use,
; compile, sell, or distribute this software, either in source code
; form or as a compiled binary, for any purpose, commercial or
; non-commercial, and by any means.

length_counter_research::
  call lcd_on_blank
  ei

  ; Turn on APU
  ld hl, rNR52
  xor a
  ld [hl], a
  ld a, $88
  ld [hl-], a
  cpl
  ld [hl-], a
  ld [hl-], a

  ; 1. Length counters do not automatically reload per note the way
  ; TIMA reloads from TMA.  If NRx1 is not rewritten, a second
  ; consecutive note lasts the maximum length: 1 s (wave) or 1/4 s
  ; (pulse or noise).
  ld hl, rNR11
  ld a, $B7
  ld [hl+], a
  ld [hl+], a
  ld [hl+], a
  ld a, $C7
  ld [hl], a
  ld b, 10
  call wait_b_frames
  ld a, $C7
  ldh [rNR14], a
  ld b, 30
  call wait_b_frames

  ; 2. Length counters continue to tick after rewriting NRx1, so long
  ; as the length counter isn't paused by turning off NRx4 bit 6.
  ld a, $97
  ldh [rNR11], a
  ld a, $C6
  ldh [rNR14], a
  ld b, 15
  call wait_b_frames

  ; Wait between setting length and playing without first pausing
  ; the length counter
  ld a, $97
  ldh [rNR11], a
  ld b, 8
  call wait_b_frames
  ld a, $C6
  ldh [rNR14], a
  ld b, 15
  call wait_b_frames

  ; bit 6 = 0 pauses length counter
  xor a
  ldh [rNR14], a
  ld a, $97
  ldh [rNR11], a
  ld a, $C6
  ldh [rNR14], a
  ld b, 15
  call wait_b_frames

  ; 3. DMG receives writes to length counters while APU is turned
  ; off in NR52, and GBC does not.

  ; Turn off APU, write length, turn on APU
  ld hl, rNR52
  xor a
  ld [hl], a
  ld a, $B7
  ldh [rNR11], a
  ld a, $88
  ld [hl-], a
  cpl
  ld [hl-], a
  ld [hl-], a
  
  ; Play a note with this length
  ld hl, rNR12
  ld a, $B7
  ld [hl+], a
  ld [hl+], a
  ld a, $C7
  ld [hl], a

  ld b, 90
  call wait_b_frames

  xor a
  ldh [rNR52], a
  jp lcd_off

wait_b_frames:
  push bc
  ld hl, rIE
  call wait_vblank_irq
  pop bc
  dec b
  jr nz, wait_b_frames
  ret
