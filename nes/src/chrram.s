;
; Trivial CHR RAM loader for NES
; Copyright 2011 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;
.include "nes.inc"
.include "mmc1.inc"
.import unpb53_xtiles
.importzp ciSrc, ciDst
.export load_continue_chr_far

.segment "BANK01"
continuetiles_chr:
  .incbin "obj/nes/continuetiles.chr.pb53"

.proc load_continue_chr_far
  lda #0
  sta PPUADDR
  sta PPUADDR
  ldy #<continuetiles_chr
  lda #>continuetiles_chr
  ldx #64
  sty ciSrc+0
  sta ciSrc+1
  jsr unpb53_xtiles
  jmp bankrts
.endproc


