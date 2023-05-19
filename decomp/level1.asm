include "../gameboy/src/hardware.inc"

section "tilemapcol", WRAM0
wMapCol: ds 16

section "stack", WRAM0, ALIGN[1]
wStackTop: ds 64
wStackStart:

section "main", ROM0

main:
  ; load tile set: white, black, dark gray
  ld hl, $9000
  xor a
  ld c, 16
  rst memset_tiny
  cpl
  ld c, 16
  rst memset_tiny
  ld c, 16
  .loadtile2:
    cpl
    ld [hl+], a
    dec c
    jr nz, .loadtile2

  ; now try loading a tilemap
  ld hl, level1
  ld de, $9800
  .colloop:
    push de
    call map_decode_one_col
    pop de
    push de
    push hl
    call blit_one_col
    pop hl
    pop de
    ld a, e
    add 2
    ld e, a
    cp 20
    jr c, .colloop

  ld a, %11100100
  ldh [rBGP], a
  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_BG9800|LCDCF_BG8800
  ldh [rLCDC], a
  xor a
  ldh [rIF], a
  ld a, IEF_VBLANK
  ldh [rIE], a
  ei
forever:
  halt
  nop
  jr forever

;;
; decodes one column of map metatiles from [HL] to wMapCol
; @param HL pointer to start of column
; @return HL at end of column
map_decode_one_col:

  ; Phase 1: decoding terrain
  ld a, [hl+]
  ld c, a
  ld a, [hl+]
  ld b, a
  ld de, wMapCol
  .fetchloop:
    xor a
    sla c
    rl b
    jr nc, .skip_map_fetch
      ld a, [hl+]
    .skip_map_fetch:
    ld [de], a
    inc de
    ld a, e
    xor low(wMapCol + 16)
    jr nz, .fetchloop
    
  ; Phase 2: decoding Markov
  push hl
  ld hl, wMapCol
  ld b, 16
  .markovloop:
    ld a, [hl]
    or a
    jr nz, .skip_markov
      ld a, c
      add low(mt_next)
      ld e, a
      adc high(mt_next)
      sub e
      ld d, a
      ld a, [de]
    .skip_markov:
    ld [hl+], a
    ld c, a
    dec b
    jr nz, .markovloop

  pop hl
  ret

;;
; Draws wMapCol to tilemap at DE
blit_one_col:
  ld b, b
  ld bc, wMapCol
  .blkloop:
    ld a, [bc]
    add low(metatile_defs >> 2)
    ld l, a
    adc high(metatile_defs >> 2)
    sub l
    ld h, a
    add hl, hl
    add hl, hl
    ld a, [hl+]
    ld [de], a
    inc e
    ld a, [hl+]
    ld [de], a
    dec e
    set 5, e
    ld a, [hl+]
    ld [de], a
    inc e
    ld a, [hl+]
    ld [de], a
    ld a, e
    add 32-1
    ld e, a
    adc d
    sub e
    ld d, a
    inc bc
    ld a, c
    xor low(wMapCol+16)
    jr nz, .blkloop
  ret



section "leveldata", ROM0
level1:
  dw %000001000000000
  db 1
  dw %000001000000000
  db 1
  dw %000000010000000
  db 1
  dw %000000010000000
  db 1
  dw %000000010000000
  db 1
  dw %000000100000000
  db 16
  dw %000000010000000
  db 1
  dw %000000100000000
  db 17
  dw %000000010000000
  db 1
  dw %000000010000000
  db 1

mt_next:
  db 0, 2, 2, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 1, 1

section "metatile_defs", ROM0, align[2]
metatile_defs:
  db 0, 0, 0, 0
  db 1, 1, 2, 2
  db 2, 2, 2, 2
  db 0, 0, 0, 0

  db 0, 0, 0, 0
  db 0, 0, 0, 0
  db 0, 0, 0, 0
  db 0, 0, 0, 0

  db 0, 0, 0, 0
  db 0, 0, 0, 0
  db 0, 0, 0, 0
  db 0, 0, 0, 0

  db 0, 0, 0, 0
  db 0, 0, 0, 0
  db 0, 0, 0, 0
  db 0, 0, 0, 0

  db 1, 0, 1, 0
  db 0, 2, 0, 2

; Administrative stuff ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "header", ROM0[$100]
  nop
  jp init
  ds 76, $00
init:
  di
  ld sp, wStackStart
  call lcd_off
  jp main

section "vblank_isr", ROM0[$40]
  reti

section "ppuclear", ROM0
;;
; Waits for forced blank (rLCDC bit 7 clear) or vertical blank
; (rLY >= 144).  Use before VRAM upload or before clearing rLCDC bit 7.
busy_wait_vblank::
  ; If rLCDC bit 7 already clear, we're already in forced blanking
  ldh a,[rLCDC]
  rlca
  ret nc

  ; Otherwise, wait for LY to become 144 through 152.
  ; Most of line 153 is prerender, during which LY reads back as 0.
.wait:
  ldh a, [rLY]
  cp 144
  jr c, .wait
  ret

lcd_off::
  call busy_wait_vblank

  ; Use a RMW instruction to turn off only bit 7
  ld hl, rLCDC
  res 7, [hl]
  ret

section "memset_tiny",ROM0[$08]
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

