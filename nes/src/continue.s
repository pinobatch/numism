.include "nes.inc"
.include "global.inc"
.include "popslide.inc"

; VRAM map
;
; 00-37 UI tiles from continuetiles.png

NUM_STAGES = 3
COINS_PER_STAGE = 10
STAGE_SEL_POS = $2000+11+32*5

TILE_BORDER = $00
TILE_BLANK = $01
TILE_TLCORNER = $02
TILE_HBAR = $03
TILE_TRCORNER = $04
TILE_COINSPIN = $10
TILE_CHECKMARK = $15
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
cursor_y: .res 1

.code

.proc continue_main
  lda #0
  sta cur_stage
  lda #0
  sta cursor_y

  jsr popslide_init
  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  sta PPUMASK
  ldx #$20
  tay
  lda #$01
  jsr ppu_clear_nt

  ; TODO: Up and Down to pick a coin
  ; TODO: Checkmarks for passing or not
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

  ; Write
  ldx #0
  ldy #COINS_PER_STAGE/2
  jsr draw_coin_title_map
  jsr popslide_terminate_blit
  ldx #COINS_PER_STAGE/2
  ldy #COINS_PER_STAGE - COINS_PER_STAGE/2
  jsr draw_coin_title_map
  jsr popslide_terminate_blit
  :
    jsr draw_one_coin_title
    jsr popslide_terminate_blit
    lda titles_draw_progress
    cmp #COINS_PER_STAGE
    bcc :-

loop:
  jsr read_pads
  ldx #0
  jsr autorepeat

  lda new_keys
  lsr a
  bcc notRight
    lda cur_stage
    cmp #NUM_STAGES - 1
    bcs padDone
    inc cur_stage
    bcc stageChanged
  notRight:
  lsr a
  bcc notLeft
    lda cur_stage
    beq padDone
    dec cur_stage
  stageChanged:
    jsr draw_stage_number
    jmp padDone
  notLeft:
  lsr a
  bcc notDown
    lda cursor_y
    cmp #COINS_PER_STAGE - 1
    bcs padDone
    inc cursor_y
    bcc padDone
  notDown:
  lsr a
  bcc notUp
    lda cursor_y
    beq padDone
    dec cursor_y
  notUp:
  padDone:

  ; Draw changes
  jsr draw_one_coin_title

  ; Draw cursor sprite
  lda #$FF
  sta OAM+0
  lda cursor_y
  asl a
  asl a
  asl a
  adc #87
  sta OAM+4
  lda #TILE_RARROW
  sta OAM+5
  lda #0
  sta OAM+6
  lda #48
  sta OAM+7
  ldx #8
  jsr ppu_clear_oam

  lda nmis
  :
    cmp nmis
    beq :-
  lda #0
  sta OAMADDR
  lda #>OAM
  sta OAM_DMA
  jsr popslide_terminate_blit
  ldx #0
  ldy #200
  lda #VBLANK_NMI|BG_0000|OBJ_0000
  sec
  jsr ppu_screen_on

  lda new_keys
  and #KEY_B
  bne :+
    jmp loop
  :
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
 
;;
; Draw tilemap data for Y coin titles, each 21 bytes, starting at X
.proc draw_coin_title_map
rowsleft = $01
rowid = $00
  sty rowsleft
  rowloop:
    stx rowid
    ldx popslide_used
    txa
    clc
    adc #21+3
    sta popslide_used
    lda rowid
    clc
    adc #6
    sec
    ror a
    sta popslide_buf,x
    lda #6<<3
    ror a
    lsr popslide_buf,x
    ror a
    lsr popslide_buf,x
    ror a
    sta popslide_buf+1,x
    lda #21-1
    sta popslide_buf+2,x
    lda #TILE_BLANK
    sta popslide_buf+3,x
    sta popslide_buf+23,x
    lda #TILE_CHECKMARK
    sta popslide_buf+6,x
    lda rowid
    cmp #9
    bcc :+
      lda #$FF-1
    :
    adc #TILE_STAGE_ONES+1
    sta popslide_buf+5,x
    lda #TILE_STAGE_TENS0/2
    rol a
    sta popslide_buf+4,x
    txa
    clc
    adc #6
    lda rowid
    jsr txtrow_part
    ldx rowid
    inx
    dec rowsleft
    bne rowloop
  rts
.endproc

;;
; Writes the tiles for 1bpp row A to popslide buf + X + 7
.proc txtrow_part
  asl a
  asl a
  asl a
  ora #$80
  tay
  loop:
    tya
    sta popslide_buf+7,x
    sta popslide_buf+15,x
    inx
    iny
    tya
    and #$07
    bne loop
bail1:
  rts
.endproc

.proc draw_one_coin_title
  ; if a title remains to be drawn, and the buffer is empty, draw one
  ldx popslide_used
  cpx #POPSLIDE_SLACK+1
  bcs txtrow_part::bail1
  lda titles_draw_progress
  cmp #COINS_PER_STAGE
  bcs txtrow_part::bail1
  jsr clearLineImg
  lda cur_stage
  asl a
  asl a
  adc cur_stage
  asl a
  adc titles_draw_progress
  asl a  ; A = stage * 20 + row * 2
  tax
  ldy coin_names+0,x
  lda coin_names+1,x
  ldx #2
  jsr vwfPuts

  lda titles_draw_progress
  asl a
  asl a
  asl a
  ora #$80
  inc titles_draw_progress
  jmp nstripe_1bpp_from_lineImg
.endproc

.rodata
continue_stripes:
  ; Palette
  .dbyt $3F00
  .byte 32-1
  ; DEBUG: 16x14-tile 1bpp area highlighted in pale blue shades
  .byte $0F,$1A,$2A,$20, $0F,$00,$10,$20, $0F,$3C,$0F,$3C, $0F,$0F,$32,$32
  .byte $0F,$1A,$10,$20, $0F,$00,$10,$20, $0F,$00,$10,$20, $0F,$00,$10,$20

  ; Attribute map, with 1bpp area
  .dbyt $23C8
  .byte 32-1
  .byte $00,$00,$80,$a0,$e0,$f0,$30,$00
  .byte $00,$00,$88,$aa,$ee,$ff,$33,$00
  .byte $00,$00,$88,$aa,$ee,$ff,$33,$00
  .byte $00,$00,$88,$aa,$ee,$ff,$33,$00

  ; Top and bottom borders
  .dbyt $2000+32*27
  .byte 64-1+NSTRIPE_RUN, $00
  .dbyt $2000+32*25
  .byte 64-1+NSTRIPE_RUN, $00
  .dbyt $2000+32*23
  .byte 64-1+NSTRIPE_RUN, $00
  .dbyt $2000+32*21
  .byte 64-1+NSTRIPE_RUN, $00

  ; Logo
  .dbyt $2000+7+32*1
  .byte 18-1
  .byte $08,$16,$0B,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$08,$09,$0A,$0B
  .dbyt $2000+7+32*2
  .byte 18-1
  .byte $18,$01,$1B,$18,$01,$1B,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$18,$19,$1A,$1B
  .dbyt $2000+7+32*3
  .byte 18-1
  .byte $28,$17,$2B,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F,$28,$29,$2A,$2B
  .dbyt $2000+7+32*5
  .byte 4-1
  .byte $4C,$4D,$4E,$4F

  ; 73 left. What else fits?
  .byte $FF

word_Stage:
  .byte "Stage", 0
