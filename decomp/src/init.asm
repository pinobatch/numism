include "src/hardware.inc"
include "src/global.inc"

section "stack", WRAM0, ALIGN[1]
wStackTop: ds 64
wStackStart:

section "header", ROM0[$100]
  nop
  jp init
  ds 76, $00
init:
  di
  ld sp, wStackStart
  call lcd_off
  ld a, $FF
  ldh [hCurKeys], a
  ld hl, hramcode_LOAD
  ld de, hramcode_RUN
  call memcpy_pascal16
  xor a
  ldh [hVblanks], a
  ld hl, wShadowOAM
  ld c, 160
  rst memset_tiny
  call run_dma
  jp main

section "memset_tiny",ROM0[$08]
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

section "memset_inc",ROM0
;;
; Writes C bytes of value A, A+1, ..., A+C-1 starting at HL.
memset_inc::
  ld [hl+],a
  inc a
  dec c
  jr nz,memset_inc
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
  fallthrough memcpy

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

section "HRAMCODE_src", ROM0
;;
; While OAM DMA is running, the CPU keeps fetching instructions
; while ROM and WRAM are inaccessible.  A program needs to jump to
; HRAM and busy-wait 160 cycles until OAM DMA finishes.
hramcode_LOAD:
  dw hramcode_RUN_end-hramcode_RUN
load "HRAMCODE", HRAM
hramcode_RUN:

;;
; Copy a display list from shadow OAM to OAM
; @param HL address to read once while copying is in progress
; @return A = value read from [HL]
run_dma::
  ld a, wShadowOAM >> 8
  ldh [rDMA],a
  ld b, 40
.loop:
  dec b
  jr nz,.loop
  ret

hramcode_RUN_end:
endl
