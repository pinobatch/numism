.include "nes.inc"
.include "global.inc"
.include "popslide.inc"

; VRAM map
;
; 00-37 UI tiles from continuetiles.png

NUM_STAGES = 3
STAGE_SEL_POS = $2000+11+32*10

TILE_BORDER = $00
TILE_BLANK = $01
TILE_TLCORNER = $02
TILE_HBAR = $03
TILE_TRCORNER = $04
TILE_COINSPIN = $10
TILE_CHECKMARK= $15
TILE_LARROW = $20
TILE_RARROW = $21
TILE_VBAR = $22
TILE_BLCORNER = $23
TILE_BRCORNER = $24
TILE_OKSYMBOL = $30
TILE_NGSYMBOL = $33
TILE_LARROW_DISABLED = $36
TILE_RARROW_DISABLED = $37
TILE_STAGE_ONES = $40
TILE_STAGE_TENS0 = $4A
TILE_STAGE_TENS1 = $4B
TILE_STAGE_LABEL = $4C

; 00-3F: UI tiles
; 40-49: digits 0-9
; 4A:    current stage - 1
; 4B:    current stage
; 4C-4F: "Stage"

.bss
cur_stage: .res 1
titles_draw_progress: .res 1

.code

.proc continue_main
  lda #1
  sta cur_stage

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

  ; Load digits
  jsr clearLineImg
  lda #9
  digitloop:
    pha
    asl a
    asl a
    sec
    rol a
    tax  ; 1, 9, 17, 23, ...
    pla
    pha
    ora #'0'
    jsr vwfPutTile
    pla
    sec
    sbc #1
    bpl digitloop
  ldx #0
  lda #TILE_STAGE_ONES
  ldy #$FA
  jsr nstripe_2bpp_from_lineImg
  jsr popslide_terminate_blit

  ; Write "Stage"
  jsr clearLineImg
  ldx #0
  lda #>word_Stage
  ldy #<word_Stage	
  jsr vwfPuts
  lda #TILE_STAGE_LABEL
  clc
  ldx #0
  ldy #%11110100
  jsr nstripe_2bpp_from_lineImg
  jsr draw_stage_number
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

STAGE_ARROWS_POS = $2000+7+32*10

.proc draw_stage_number
  ; Draw digit used for x1-x9
  lda #0
  sta titles_draw_progress
  jsr clearLineImg
  lda cur_stage
  beq is_stage1
    ora #'0'
    ldx #4
    jsr vwfPutTile
  is_stage1:

  ; Draw digit used for x0 and stage number
  lda cur_stage
  cmp #9
  bcc not_stage10
    lda #'1'
    ldx #7
    jsr vwfPutTile
    clc
    lda #$FF
  not_stage10:
  adc #'1'
  ldx #12
  jsr vwfPutTile

  ; Write these digits to VRAM
  ldy #$F2
  lda #TILE_STAGE_TENS0
  ldx #4
  jsr nstripe_2bpp_from_lineImg

  ; Add left/right arrow control
  ldx popslide_used
  txa
  clc
  adc #6
  sta popslide_used
  lda #>STAGE_SEL_POS
  sta popslide_buf+0,x
  lda #<STAGE_SEL_POS
  sta popslide_buf+1,x
  lda #3-1
  sta popslide_buf+2,x
  lda cur_stage
  cmp #1
  lda #TILE_LARROW
  bcs :+
    lda #TILE_LARROW_DISABLED
  :
  sta popslide_buf+3,x
  lda #TILE_STAGE_TENS1
  sta popslide_buf+4,x
  lda cur_stage
  cmp #NUM_STAGES-1
  lda #TILE_RARROW
  bcc :+
    lda #TILE_RARROW_DISABLED
  :
  sta popslide_buf+5,x
  rts
.endproc

.rodata
continue_stripes:
  ; Palette
  .dbyt $3F00
  .byte 32-1
  .byte $0F,$1A,$2A,$20, $0F,$00,$10,$20, $0F,$3C,$0F,$3C, $0F,$0F,$32,$32
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
  .byte 4-1
  .byte $4C,$4D,$4E,$4F

  ; 73 left. What else fits?
  .byte $FF

word_Stage:
  .byte "Stage", 0
