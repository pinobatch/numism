include "../gameboy/src/hardware.inc"

section "tilemapcol", WRAM0
wMapCol: ds 16

section "stack", WRAM0, ALIGN[1]
wStackTop: ds 64
wStackStart:

section "main", ROM0

main:
  ld hl, level1chr_2b
  ld de, $9000
  call memcpy_pascal16

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
  dw %0000001000000000
  db 1
  dw %0100000010000000
  db 12,1
  dw %0100000100000000
  db 13,16
  dw %0100000010000000
  db 13,1
  dw %0100000100000000
  db 14,17
  dw %0000001000000000
  db 19
  dw %0000001000000000
  db 15
  dw %0000100100000000
  db 3, 1
  dw %1010000000000000
  db 12, 8
  dw %1110000000000000
  db 14, 12, 9

mt_next:
  db 0, 2, 2, 4, 4, 0, 0, 0
  db 10, 11, 1, 1, 0, 0, 0, 1
  db 1, 1, 1, 20, 1

section "metatile_defs", ROM0, align[2]
metatile_defs:
  db $00,$00,$00,$00  ; sky
  db $4E,$4D,$03,$03  ; ground top
  db $03,$03,$03,$03  ; ground inside
  db $08,$09,$18,$19  ; ladder top

  db $18,$19,$18,$19  ; ladder inside
  db $00,$00,$00,$00
  db $00,$00,$00,$00
  db $00,$00,$00,$00

  db $10,$11,$20,$21  ; bushtl
  db $12,$13,$22,$23  ; bushtr
  db $30,$31,$0C,$03  ; bushbl
  db $32,$33,$03,$0F  ; bushbr

  db $00,$04,$00,$14  ; cloudL
  db $05,$06,$15,$16  ; cloudC
  db $07,$00,$17,$00  ; cloudR
  db $28,$29,$38,$39  ; smbush

  db $00,$46,$00,$3F  ; flower1
  db $00,$47,$00,$3F  ; flower2
  db $00,$2F,$00,$3F  ; flower3
  db $00,$2C,$00,$3F  ; flower4

  db $00,$3C,$00,$3F  ; flower4 extended

section "bgchr", ROMX, BANK[1]

level1chr_2b:
  dw .end-.start
.start:
  incbin "level1chr.2b"
.end:

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

section "memcpy", ROM0
;;
; Copy a string preceded by a 2-byte length from HL to DE.
; @param HL source address
; @param DE destination address
memcpy_pascal16::
  ld a, [hl+]
  ld c, a
  ld a, [hl+]
  ld b, a
  ; fall through to memcpy

;;
; Copies BC bytes from HL to DE.
; @return A: last byte copied; HL at end of source;
; DE at end of destination; B=C=0
memcpy::
  ; Increment B if C is nonzero
  dec bc
  inc b
  inc c
.loop:
  ld a, [hl+]
  ld [de],a
  inc de
  dec c
  jr nz,.loop
  dec b
  jr nz,.loop
  ret
