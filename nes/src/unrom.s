;
; UNROM driver for NES
; Copyright 2011-2015 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

.include "mmc1.inc"  ; implements a subset of the same interface
.import nmi_handler, reset_handler, irq_handler, bankcall_table

.export bccwrap_forward, bccwrap_inxrts

.segment "INESHDR"
  .byt "NES",$1A  ; magic signature
  .byt 4          ; size of PRG ROM in 16384 byte units
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $21        ; lower mapper nibble, vertical mirroring
  .byt $00        ; upper mapper nibble
  
.segment "ZEROPAGE"
lastPRGBank: .res 1
bankcallsaveA: .res 1

; Reserve $FFE0-$FFFF of the fixed bank for things needed by
; obscure tests
.segment "STUB15"
bccwrap_forward:
  bcc *+$21
  inx
bccwrap_inxrts:
  inx
  rts

  ; The vectors
  .res bccwrap_forward+$1A-*
  .addr nmi_handler, reset_handler, irq_handler

.segment "CODE"
;;
; Changes $8000-$BFFF to point to a 16384 byte chunk of PRG ROM
; starting at $4000 * A.
; On UNROM this trashes Y, NF, and ZF, and preserves VF and CF.
.proc setPRGBank
  sta lastPRGBank
  tay
  sta identity16,y
  rts
.endproc

; Inter-bank method calling system.  There is a table of up to 85
; different methods that can be called from a different PRG bank.
; Typical usage:
;   ldx #move_character
;   jsr bankcall
.proc bankcall
  sta bankcallsaveA
  lda lastPRGBank
  pha
  lda bankcall_table+2,x
  jsr setPRGBank
  lda bankcall_table+1,x
  pha
  lda bankcall_table,x
  pha
  lda bankcallsaveA
  rts
.endproc

; Functions in the bankcall_table MUST NOT exit with 'rts'.
; Instead, they MUST exit with 'jmp bankrts'.
.proc bankrts
  sta bankcallsaveA
  pla
  jsr setPRGBank
  lda bankcallsaveA
  rts
.endproc

.segment "RODATA"
; To avoid bus conflicts, bankswitch needs to write a value
; to a ROM address that already contains that value.
identity16:
  .repeat 16, I
    .byte I
  .endrepeat
