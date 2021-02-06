.include "nes.inc"
.include "global.inc"
.include "popslide.inc"

.code

.proc continue_main
  jsr popslide_init
  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  sta PPUMASK
  ldx #$20
  tay
  lda #$01
  jsr ppu_clear_nt

  ; TODO: Color logo
  ; TODO: Draw stage number
  ; TODO: Draw digits
  ; TODO: Set up VWF canvas for coin titles on this page
  ; TODO: Draw coin titles on this page
  ; TODO: Left and Right to choose a page
  ; TODO: Up and Down to pick a coin
  ; TODO: Checkmarks for passes
  ; TODO: A and B to hide or show coin description
  ; TODO: OK or NG in coin description

  ldx #>continue_stripes
  lda #<continue_stripes
  jsr nstripe_append
  lda nmis
  :
    cmp nmis
    beq :-
  jsr popslide_terminate_blit

loop:
  jsr read_pads
  lda nmis
  :
    cmp nmis
    beq :-
  ldx #0
  ldy #0
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  jsr ppu_screen_on

  lda new_keys
  and #KEY_B
  beq loop
  rts
.endproc

.rodata
continue_stripes:
  ; Palette
  .dbyt $3F00
  .byte 32-1
  .byte $0F,$1A,$2A,$20, $0F,$00,$10,$20, $0F,$00,$10,$20, $0F,$00,$10,$20
  .byte $0F,$00,$10,$20, $0F,$00,$10,$20, $0F,$00,$10,$20, $0F,$00,$10,$20

  ; Border
  .dbyt $2000
  .byte 64-1+NSTRIPE_RUN, $00
  .dbyt $2000+32*2
  .byte 64-1+NSTRIPE_RUN, $00
  .dbyt $2000+32*26
  .byte 64-1+NSTRIPE_RUN, $00
  .dbyt $2000+32*28
  .byte 64-1+NSTRIPE_RUN, $00

  ; Logo
  .dbyt $2000+7+32*6
  .byte 18-1
  .byte $08,$16,$0B,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$08,$09,$0A,$0B
  .dbyt $2000+7+32*7
  .byte 18-1
  .byte $18,$01,$1B,$18,$01,$1B,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$18,$19,$1A,$1B
  .dbyt $2000+7+32*8
  .byte 18-1
  .byte $28,$17,$2B,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F,$28,$29,$2A,$2B
  .dbyt $2000+7+32*10
  .byte 7-1
  .byte $4C,$4D,$4E,$01,$20,$4B,$21

  ; 70 left. What else fits?
  .byte $FF

