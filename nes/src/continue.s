.include "nes.inc"
.include "global.inc"
.include "popslide.inc"

; VRAM map
;
; 00-37 UI tiles from continuetiles.png

NUM_STAGES = 3
COINS_PER_STAGE = 10
COIN_DESC_LINES = 4
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
desc_draw_progress: .res 1
cursor_y: .res 1
want_desc_open: .res 1
desc_y: .res 1
desc_text_ptr: .res 2

.code

.proc continue_main
  lda #0
  sta cur_stage
  lda #0
  sta cursor_y
  sta want_desc_open
  lda #$FF
  sta desc_y

  jsr popslide_init
  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  sta PPUMASK
  ldx #$20
  tay
  lda #$01
  jsr ppu_clear_nt

  ; TODO: A and B to hide or show coin description
  ; TODO: Checkmarks for passing or not
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
  asl a
  bcc notA
    lda #1
    sta want_desc_open
  notA:
  bpl notB
    lda #0
    sta want_desc_open
  notB:

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
  lda desc_y
  bmi desc_y_is_hidden
    lda #$FF
    bne have_arrow_y
  desc_y_is_hidden:
    lda cursor_y
    asl a
    asl a
    asl a
    adc #87
  have_arrow_y:
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
  and #KEY_START
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
  sta desc_draw_progress
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
    lda rowid
    jsr calc_row_vram_address

    ; if this row is one of the blank rows below the last coin name,
    ; draw it as blank
    lda rowid
    cmp #COINS_PER_STAGE
    bcc row_is_real
    cmp #COINS_PER_STAGE+COIN_DESC_LINES+1
    bcs done
    lda #(21-1)|NSTRIPE_RUN
    sta popslide_buf+2,x
    lda #TILE_BLANK
    sta popslide_buf+3,x
    lda #4
    bne have_packetlen
  row_is_real:
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
    lda rowid
    jsr txtrow_part

    lda #21+3
  have_packetlen:
    clc
    adc popslide_used
    sta popslide_used
    ldx rowid
    inx
    dec rowsleft
    bne rowloop
  done:
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

;;
; Gets a pointer to the name and description of coin cur_stage*10+A.
; @param A Y position
; @param cur_stage which stage
; @return AY pointer to coin name; X = (cur_stage*10+A)*2;
; $00 trashed
.proc get_coin_title_ptr
  sta $00
  lda cur_stage
  asl a
  asl a
  adc cur_stage
  asl a
  adc $00
  asl a  ; A = stage * 20 + row * 2
  tax
  ldy coin_names+0,x
  lda coin_names+1,x
  rts
.endproc

.proc draw_one_coin_title
  ; Draw only if the buffer is empty enough
  ldx popslide_used
  cpx #POPSLIDE_SLACK+1
  bcs txtrow_part::bail1

  ; Priority before drawing the titles to CHR RAM is erasing an
  ; unwanted description from the tilemap.  A description is
  ; "unwanted" if it is on screen (desc_y bit 7 clear) and either the
  ; user wants to close it or it's on a row other than the cursor's.
  lda desc_y
  bmi dont_erase_desc
  ldy want_desc_open
  beq yes_erase_desc
  cmp cursor_y
  beq dont_erase_desc
  yes_erase_desc:
    sta $4444
    tax  ; X = old desc_y
    ldy #$FF
    sty desc_y
    iny
    sty desc_draw_progress  ; Restart description drawing
    ldy #COIN_DESC_LINES+2
    jmp draw_coin_title_map
  dont_erase_desc:

  ; if a title remains to be drawn, and the buffer is empty, draw one
  lda titles_draw_progress
  cmp #COINS_PER_STAGE
  bcs draw_description_step
  jsr clearLineImg
  lda titles_draw_progress
  jsr get_coin_title_ptr
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

.proc draw_description_step
  lda want_desc_open
  beq txtrow_part::bail1
  ; By now we know the user wants the description open.
  ; Steps:
  ; 0 draw empty frame
  ; 1-4 draw one line of text
  ; 5 draw into frame
  ldx popslide_used
  ldy desc_draw_progress
  beq :+
    jmp not_step0
  :
    ; Packet layout
    ; 0 left column
    ; 9 right column
    ; 18 hbar at TR border
    ; 22, 26, 30, 34 interior
    ; 38 bottom border
    txa
    clc
    adc #22
    sta popslide_used
    sta $4444
    ; Calculate starting address of first 4 packets
    lda cursor_y
    sta desc_y
    jsr calc_row_vram_address
    lda popslide_buf+1,x
    clc
    adc #19
    sta popslide_buf+19,x
    clc
    adc #1
    sta popslide_buf+10,x
    clc
    adc #13
    sta popslide_buf+23,x
    lda popslide_buf+0,x
    sta popslide_buf+9,x
    sta popslide_buf+18,x
    adc #0
    sta popslide_buf+22,x

    ; Write 
    lda #(6-1)|NSTRIPE_DOWN
    sta popslide_buf+2,x
    sta popslide_buf+11,x
    lda #0
    sta popslide_buf+20,x
    lda #TILE_HBAR
    sta popslide_buf+21,x
    lda #TILE_TLCORNER
    sta popslide_buf+3,x
    lda #TILE_BLCORNER
    sta popslide_buf+8,x
    lda #TILE_TRCORNER
    sta popslide_buf+12,x
    lda #TILE_BRCORNER
    sta popslide_buf+17,x
    ldy #4
    lda #TILE_VBAR
    :
      sta popslide_buf+4,x
      sta popslide_buf+13,x
      inx
      dey
      bne :-

    ; Next packet's address is in place.
    ldy #COIN_DESC_LINES
    ldx popslide_used
    frameinteriorloop:
      lda popslide_buf+1,x
      clc
      adc #32
      sta popslide_buf+5,x
      lda popslide_buf+0,x
      adc #0
      sta popslide_buf+4,x
      lda #(19-1)|NSTRIPE_RUN
      sta popslide_buf+2,x
      tya
      beq :+
        lda #TILE_HBAR^TILE_BLANK
      :
      eor #TILE_HBAR
      sta popslide_buf+3,x
      inx
      inx
      inx
      inx
      dey
      bpl frameinteriorloop
    stx popslide_used
    
    ; TODO: Draw center and bottom
    ; TODO: Look up coin name and fast-forward to coin description
    inc desc_draw_progress
  bail1:
    rts
  not_step0:
  cpy #COIN_DESC_LINES+1
  bcc is_description_line
  bne bail1
    ; Finish the job by writing the tilemap showing the window
    rts
  is_description_line:

  rts
.endproc
  

.proc calc_row_vram_address
  ; calculate VRAM address of row
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
  rts
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
