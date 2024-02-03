include "src/hardware.inc"
include "src/global.inc"

def GBC_BGP_EMULATION equ 1

section "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM:: ds 160
wOAMUsed:: ds 1

section "PPU various variables", HRAM
hVblanks:: ds 1
hCapability:: ds 1

section "vblank_isr", ROM0[$40]
  push af
  ld a, [hVblanks]
  inc a
  ldh [hVblanks], a
  pop af
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

;;
; Moves sprites in the display list from wShadowOAM+[wOAMUsed]
; through wShadowOAM+$9C offscreen by setting their Y coordinate to
; 0, which is completely above the screen top (16).
lcd_clear_oam::
  ; Destination address in shadow OAM
  ld hl, wOAMUsed
  ld a, [hl]
  and $FC
  ld l,a

  ; iteration count
  rrca
  rrca
  add 256 - 40
  ld c,a

  xor a
.rowloop:
  ld [hl+],a
  inc l
  inc l
  inc l
  inc c
  jr nz, .rowloop
  ret

load_full_nam::
  ld bc,256*20+18
  fallthrough load_nam
;;
; Copies a B column by C row tilemap from HL to screen at DE.
load_nam::
  push bc
  push de
  .byteloop:
    ld a,[hl+]
    ld [de],a
    inc de
    dec b
    jr nz,.byteloop

  ; Move to next screen row
  pop de
  ld a,32
  add e
  ld e,a
  jr nc,.no_inc_d
    inc d
  .no_inc_d:

  ; Restore width; do more rows remain?
  pop bc
  dec c
  jr nz,load_nam
  ret

;;
; Turns off rendering and clears both GBC tilemaps' attribute plane.
; @return A=0
clear_gbc_attr::
  call lcd_off
  ldh a, [hCapability]
  and $80
  add a
  ret nc

  rla
  ldh [rVBK],a
  ld hl, $9800
  ld c, l
  ld a, l
  .loop:
    rst memset_tiny
    bit 5, h
    jr z, .loop
  ldh [rVBK], a
  ret

section "hblankcopy", ROM0
;;
; Performs an hblank copy that isn't a stack copy.
; Copies 4*B bytes from DE to HL (opposite of standard memcpy)
; at 4 bytes per line.  C unchanged
hblankcopy::
  ldh a, [rLCDC]
  add a
  jr nc, .unbusy_done
  ; wait for mode not 0
.unbusy:
  ldh a, [rSTAT]
  and $03
  jr z, .unbusy
.unbusy_done:

  push bc
  ; then wait for mode 0 or 1
  ld a, [de]
  ld c, a
  inc e
  ld a, [de]
  ld b, a
  inc e
.busy:
  ldh a, [rSTAT]
  and $02
  jr nz, .busy  ; spin wait can take up to 12 cycles
  ld a, c      ; 1
  ld [hl+], a  ; 2
  ld a, b      ; 1
  ld [hl+], a  ; 2
  ld a, [de]   ; 2
  ld [hl+], a  ; 2
  inc e        ; 1
  ld a, [de]   ; 2
  ld [hl+], a  ; 2
  inc de
  pop bc
  dec b
  jr nz, hblankcopy
  ret

SECTION "load_gbc_palette", ROM0, align[3]

  if GBC_BGP_EMULATION
gbmonopalette:
  drgb $FFFFFF, $B2B2B2, $666666, $000000

;;
; Emulates mono palette feature on Game Boy Color.
; Call this only during blanking.
set_obp1::
  ldh [rOBP1],a
  ld bc,$8800 + low(rOCPS)
  jr set_gbc_mono_palette

;;
; Emulates mono palette feature on Game Boy Color.
; Call this only during blanking.
set_obp0::
  ldh [rOBP0],a
  ld bc,$8000 + low(rOCPS)
  jr set_gbc_mono_palette

;;
; Emulates mono palette feature on Game Boy Color.
; Call this only during blanking.
set_bgp::
  ldh [rBGP],a
  ld bc,$8000 + low(rBCPS)
  fallthrough set_gbc_mono_palette

;;
; Emulates mono palette setting on Game Boy Color.
; @param A BGP or OBP0 value
; @param B offset into palette memory (0, 8, 16, ..., 56) plus $80
; @param C palette port to write: LOW(rBCPS) or LOW(rOCPS)
; @return AEHL clobbered, B=0, C increased by 1, D unchanged
set_gbc_mono_palette::
  rlca
  ld e,a
  ld a,b  ; Regmap now: E=BGP<<1, A=palette offset, C=address port
  ld [$FF00+c],a
  inc c   ; C=data port
  ld b,4  ; color count
  ld h,high(gbmonopalette)
  ld a, e
  ; Regmap now: B=count of remaining colors, C=data port address,
  ;   A=E=BGP value rlc 1, HL=pointer to start of palette
.loop:
    and %00000110
    or low(gbmonopalette)
    ld l,a  ; now L points to this color so stuff it into the palette
    ld a,[hl+]
    ld [$FF00+c],a
    ld a,[hl-]
    ld [$FF00+c],a
    ld a, e  ; move to next bitfield of BGP
    rrca
    rrca
    ld e, a
    dec b
    jr nz,.loop

  ; Restore BGP value
  rrca
  ret
  endc

;;
; Loads native GBC palette data.
; @param A offset into palette memory (0, 8, 16, ..., 56) plus $80
; @param B number of bytes to copy: 8 times number of subpalettes
; @param C palette port to write: LOW(rBCPS) or LOW(rOCPS)
; @param HL data source
; @return HL at end, C increased by 1, B = 0, DE unchanged
set_gbc_palette::
  ld [$FF00+c],a
  inc c
.loop:
  ld a,[hl+]
  ld [$FF00+c],a
  dec b
  jr nz,.loop
  ret
