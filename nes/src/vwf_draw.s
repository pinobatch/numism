; NES variable width font drawing library
; Copyright 2006-2017 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.

; Change history:
; 2006-03: vwfPutTile rewritten by "Blargg" (Shay Green)
; and then adapted by Damian Yerrick to match old semantics
; 2010-06: DY skipped completely transparent pattern bytes
; 2011-11: DY added string length measuring
; 2012-01: DY added support for inverse video
; 2015-02: vwfPutTile rewritten by DY again; no more Blargg code

.include "nes.inc"
.include "popslide.inc"
.export vwfPutTile, vwfPuts, vwfPuts0
.export vwfGlyphWidth, vwfStrWidth, vwfStrWidth0
.export clearLineImg, lineImgBuf, invertTiles
.export nstripe_2bpp_from_lineImg, nstripe_1bpp_from_lineImg
.exportzp lineImgBufLen
.import vwfChrData, vwfChrWidths

; Overlap VWF line image and shadow OAM to stay out of popslide's way
; If we completely rewrite shadow OAM every frame, it's OK
lineImgBuf = $0200
lineImgBufLen = 128
FONT_HT = 8
MIN_CODEUNIT = $20

srcStr = $00
horzPos = $04
shiftedByte = $05
tileAddr = $06
shiftContinuation = $08
leftMask = $0A
rightMask = $0B

.segment "CODE"
;;
; Clears the line image buffer.
; Does not modify Y or zero page.
.proc clearLineImg
  ldx #lineImgBufLen/4-1
  lda #0
:
  .repeat 4, I
    sta lineImgBuf+lineImgBufLen/4*I,x
  .endrepeat
  dex
  bpl :-
  rts
.endproc

.macro getTileAddr
  sec
  sbc #MIN_CODEUNIT
  ; Find source address
  asl a     ; 7 6543 210-
  adc #$80  ; 6 -543 2107
  rol a     ; - 5432 1076
  asl a     ; 5 4321 076-
  tay
  and #%00000111
  adc #>vwfChrData
  sta tileAddr+1
  tya
  and #%11111000
  sta tileAddr
.endmacro

; Comment or uncomment this line to keep the shiftslide in vwfPutTile
; from crossing a page boundary.
;.res 32

;;
; Puts a 1-bit tile to position X in the line image buffer.
; In:   A = tile number
;       X = destination X position
; Trash: AXY, $05-$0B
.proc vwfPutTile
  getTileAddr

  ; Construct fast shifter
  txa
  and #%00000111
  tay
  lda leftMasks,y
  sta leftMask
  eor #$FF
  sta rightMask
  lda shiftContinuations,y
  sta shiftContinuation
  lda #>shiftslide
  sta shiftContinuation+1

  ; Process scanlines from the bottom up
  txa
  .if ::FONT_HT = 8
    ora #8-1
  .elseif ::FONT_HT = 16
    asl a
    ora #16-1
  .else
    .assert 0, error, "font size must be 8 or 16"
  .endif
  tax
  ldy #FONT_HT - 1
chrbyteloop:
  lda (tileAddr),y
  beq isBlankByte
  jmp (shiftContinuation)
shiftslide:
  rol a
  rol a
  rol a
  rol a
  rol a
  rol a
  rol a
  sta shiftedByte
  and rightMask
  ora lineImgBuf+FONT_HT,x
  sta lineImgBuf+FONT_HT,x
  lda shiftedByte
  rol a
  and leftMask
dontshift:
  ora lineImgBuf,x
  sta lineImgBuf,x
isBlankByte:
  dex
  dey
  bpl chrbyteloop
  rts

  .assert >shiftslide = >dontshift, error, "shiftslide crosses page boundary"

.pushseg
.segment "RODATA"
leftMasks:
  .repeat 8, I
    .byte $FF >> I
  .endrepeat
shiftContinuations:
  .byte <dontshift
  .repeat 7, I
    .byte <(shiftslide+I)
  .endrepeat
.popseg
.endproc

;;
; Calculates the width in pixels of a string.
; @param AAYY: string address, stored to $00-$01
; @return total pen-advance in A; strlen in Y; carry set if overflowed
; Trash: $02
.proc vwfStrWidth
str = $00
  sty str
  sta str+1
.endproc
;;
; Same as vwfStrWidth.
; @param $00-$01: string address
.proc vwfStrWidth0
str = vwfStrWidth::str
width = $02
  ldy #0
  sty width
loop:
  lda (str),y
  beq bail
  tax
  lda vwfChrWidths-32,x
  clc
  adc width
  sta width
  bcs bail
  iny
  bne loop
bail:
  lda width
  rts
.endproc

;;
; Finds both the pen-advance of a glyph and the
; columns actually occupied by opaque pixels.
; in: A = character number (32-127)
; out: A = columns containing a bit; X: pen-advance in pixels
.proc vwfGlyphWidth
  tay
  ldx vwfChrWidths-32,y
  getTileAddr
  ldy #7
  lda #0
:
  ora (tileAddr),y
  dey
  bpl :-
  rts
.endproc

;;
; Writes a string to position X, terminated by $00-$1F byte.
; In:   AAYY = string base address, stored to $00-$01
;       X = destination X position
; Out:  X = ending X position
;       $00-$01 = END of string
;       AAYY = End of string, plus one if greater than 0
; Trash: $04-$0B
.proc vwfPuts
  sty srcStr
  sta srcStr+1
.endproc
.proc vwfPuts0
  stx horzPos
loop:
  ldy #0
  lda (srcStr),y
  beq done0
  cmp #MIN_CODEUNIT
  bcc doneNewline
  .if ::MIN_CODEUNIT <> ' '
    cmp #' '
  .endif
  beq isSpace
  ldx horzPos
  jsr vwfPutTile
  ldy #0
isSpace:
  lda (srcStr),y
  inc srcStr
  bne :+
    inc srcStr+1
  :
  tax
  lda vwfChrWidths-32,x
  clc
  adc horzPos
  sta horzPos
  cmp #lineImgBufLen
  bcc loop

doneNewline:
  lda #1
done0:
  clc
  adc srcStr
  tay
  lda #0
  adc srcStr+1
  ldx horzPos 
  rts
.endproc

;;
; Inverts the first A tiles in lineImgBuf.
.proc invertTiles
  asl a
  asl a
  asl a
  .if ::FONT_HT = 16
    asl a
  .endif
  tax
  dex
invertloop:
  lda #$FF
  eor lineImgBuf,x
  sta lineImgBuf,x
  dex
  bne invertloop
  lda #$FF
  eor lineImgBuf
  sta lineImgBuf
  rts
.endproc

;;
; @param X source position
; @param C:A tile number in $0000
; @param Y[3:0] tile count
; @param Y[7:4] AND and XOR masks for colorization
.proc nstripe_2bpp_from_lineImg
vramdst = $00
srcpos = $02
tilecount = $03
and0 = $04
xor0 = $05
and1 = $06
xor1 = $07
  rol a
  rol a
  rol a
  rol a
  pha
  and #$F0
  sta vramdst+0
  pla
  rol a
  and #$1F
  sta vramdst+1
  txa
  and #$F8
  sta srcpos
  tya
  and #$0F
  sta tilecount
  tya
  and #$F0
  ldx #3
  masksloop:
    ldy #0
    asl a
    bcc :+
      dey
    :
    sty and0,x
    dex
    bpl masksloop

  ldy popslide_used
  ldx srcpos
  packetloop:
    lda vramdst+0
    sta popslide_buf+1,y
    lda tilecount
    and #3
    bne :+
      lda #4
    :
    asl a
    asl a
    asl a
    asl a
    adc #$FF
    sta popslide_buf+2,y
    sec
    adc vramdst+0
    sta vramdst+0
    lda vramdst+1
    sta popslide_buf+0,y
    adc #0
    sta vramdst+1
    iny
    iny
    iny
    tileloop:
    sliverloop:
      lda lineImgBuf+0,x
      and and0
      eor xor0
      sta popslide_buf+0,y
      lda lineImgBuf+0,x
      and and1
      eor xor1
      sta popslide_buf+8,y
      iny
      inx
      txa
      and #$07
      bne sliverloop
      tya
      clc
      adc #8
      tay
      dec tilecount
      lda tilecount
      beq done
      and #3
      bne tileloop
    sta $4444
    jmp packetloop
  done:
  sty popslide_used

  rts
.endproc

;;
; Copies a rendered line of text to CHR RAM, packing 2 8x8 pixel
; tiles into each plane.
; Plane 0 contains tiles 0, 1, 4, 5, 8, 9, 12, and 13.
; Plane 1 contains tiles 2, 3, 6, 7, 10, 11, 14, and 15.
; in:  AAYY = destination address ($0000-$1F80)
.proc nstripe_1bpp_from_lineImg
  ; TODO
  rts
.endproc


