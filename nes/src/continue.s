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
CHECKMARK_POS = $2000+9+32*6

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
passbits: .res 2 * NUM_STAGES
cur_stage: .res 1
titles_draw_progress: .res 1
desc_draw_progress: .res 1
cursor_y: .res 1
want_desc_open: .res 1
desc_y: .res 1
desc_text_ptr: .res 2

.code

.proc run_stage
  asl a
  sta cur_stage
  tax  ; cur_stage = X = stage * 2
  asl a
  asl a
  adc cur_stage
  asl a  ; A = stage * 20
  sta desc_y
  lda #1 << (COINS_PER_STAGE - 9)
  sta passbits+1,x
  lda #0
  sta passbits+0,x

  loop:
    jsr run_one_test
    ldx cur_stage
    lda passbits+1,x
    bcc :+
      ora #1 << (COINS_PER_STAGE - 7)
    :
    lsr a
    sta passbits+1,x
    ror passbits+0,x
    bcc loop
  lsr cur_stage
  rts

run_one_test:
  ldx desc_y
  lda coin_routines,x
  sta $00
  inx
  lda coin_routines,x
  sta $01
  inx
  stx desc_y
  lda #VBLANK_NMI
  sta PPUCTRL
  lda #0
  sta PPUMASK
  jmp ($0000)
.endproc

.proc continue_main
  ; Fill passbits with fake data
  lda #0
  ldy #NUM_STAGES*2-1
  :
    tya
    sta passbits,y
    dey
    bne :-
  lda #0
  jsr run_stage
  lda #1
  jsr run_stage
  lda #2
  jsr run_stage

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

  ; Write names of coins
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
  ldy want_desc_open
  bne have_arrow_y
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

  ; Draw OK/NG sprite
  ldx #8
  lda desc_draw_progress
  cmp #COIN_DESC_LINES+2
  bcc no_ok_ng_sprite
    lda desc_y
    sta $00
    jsr get_one_passbit
    lda #TILE_OKSYMBOL
    bcc :+
      lda #TILE_NGSYMBOL
    :
    sta $01
    lda #0  ; attribute
    rol a
    sta $02
    lda desc_y
    asl a
    asl a
    asl a
    adc #95
    sta $00
    lda #56
    sta $03
    ldy #3
    :
      lda $00
      sta OAM,x
      inx
      lda $01
      inc $01
      sta OAM,x
      inx
      lda $02
      sta OAM,x
      inx
      lda $03
      sta OAM,x
      inx
      clc
      adc #8
      sta $03
      dey
      bne :-
  no_ok_ng_sprite:
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

  ; If the description is on screen, request hiding it
  lda desc_y
  bmi :+
    ora #$40
    sta desc_y
  :
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

fails0 = $00
fails1 = $01
  ; Draw all checkmarks for this stage
  lda cur_stage
  asl a
  tay
  lda passbits+0,y
  sta fails0
  lda passbits+1,y
  sta fails1
  ldx popslide_used
  txa
  clc
  adc #COINS_PER_STAGE+3
  sta popslide_used
  lda #>CHECKMARK_POS
  sta popslide_buf+0,x
  lda #<CHECKMARK_POS
  sta popslide_buf+1,x
  lda #(COINS_PER_STAGE-1)|NSTRIPE_DOWN
  sta popslide_buf+2,x
  ldy #COINS_PER_STAGE
  markloop:
    lsr fails1
    ror fails0
    lda #TILE_CHECKMARK
    bcc :+
      lda #TILE_BLANK
    :
    sta popslide_buf+3,x
    inx
    dey
    bne markloop
  rts
.endproc


;;
; Returns whether one test failed.
; @param cur_stage stage to load
; @param $00 y position within stage
; @return carry clear for pass or set for fail
.proc get_one_passbit
rowid = $00
  lda rowid
  cmp #8
  lda cur_stage
  rol a
  tay
  lda passbits,y
  pha
  lda rowid
  and #$07
  tay
  pla
  :
    lsr a
    dey
    bpl :-
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

    ; Load test status into carry
    jsr get_one_passbit
    lda #TILE_CHECKMARK
    bcc :+
      lda #TILE_BLANK
    :
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
    inx
    inx
    inx
    inx
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
; Writes the tiles for 1bpp row A to popslide buf + X + 3
; and advances X by 8
.proc txtrow_part
  asl a
  asl a
  asl a
  ora #$80
  tay
.endproc
.proc txtrow_part_tiley
  loop:
    tya
    sta popslide_buf+3,x
    sta popslide_buf+11,x
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
  bcs txtrow_part_tiley::bail1

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
    and #$0F
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
  beq txtrow_part_tiley::bail1
  ; By now we know the user wants the description open.
  ; Steps:
  ; 0 draw empty frame
  ; 1-4 draw one line of text
  ; 5 draw into frame
  ldy desc_draw_progress
  bne not_step0
    lda cursor_y
    sta desc_y
    jsr calc_row_vram_address
    lda popslide_buf+1,x
    sta nstripe_left
    lda popslide_buf+0,x
    ora #$40
    tay
    ldx #>erase_border_stripes
    lda #<erase_border_stripes
    jsr nstripe_append_yhi

    ; Look up coin name and fast-forward to coin description
    lda desc_y
    jsr get_coin_title_ptr
    sta 1
    sty 0
    ldy #0
    :
      lda (0),y
      cmp #$10
      bcc found_ctrlchar
      iny
      bne :-
    found_ctrlchar:
    cmp #1  ; set up carry to skip a newline but not a NUL terminator
    tya
    adc 0
    sta desc_text_ptr
    lda 1
    adc #0
    sta desc_text_ptr+1
    inc desc_draw_progress
  bail1:
    rts
  not_step0:

  ldx popslide_used
  cpy #COIN_DESC_LINES+1
  bcc is_description_line
  bne bail1
    ; Write the tilemap for the coin description text
    ldy desc_y
    iny
    tya
    jsr calc_row_vram_address
    lda popslide_buf+1,x
    clc
    adc #4
    sta popslide_buf+1,x
    ldy #$80 + COINS_PER_STAGE * 8
    tmloop:
      clc
      lda popslide_buf+1,x
      adc #32
      sta popslide_buf+20,x
      lda popslide_buf+0,x
      adc #0
      sta popslide_buf+19,x
      lda #16-1
      sta popslide_buf+2,x
      jsr txtrow_part_tiley
      clc
      txa
      adc #16+3-8
      tax
      cpy #$80 + (COINS_PER_STAGE+COIN_DESC_LINES)*8
      bne tmloop
    stx popslide_used
    inc desc_draw_progress
    rts
  is_description_line:
  ; Write the text
  jsr clearLineImg
  ldx #2
  lda desc_text_ptr+1
  ldy desc_text_ptr
  jsr vwfPuts
  sta desc_text_ptr+1
  sty desc_text_ptr
  lda desc_draw_progress
  inc desc_draw_progress
  asl a
  asl a
  asl a
  adc #$80 + (COINS_PER_STAGE - 1) * 8
  jmp nstripe_1bpp_from_lineImg
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

; DEBUG: 16x14-tile 1bpp area highlighted in pale blue shades
.if 1
  P0SHADE = $3C
  P1SHADE = $32
.else
  P0SHADE = $20
  P1SHADE = $20
.endif

continue_stripes:
  ; Palette
  .dbyt $3F01
  .byte 31-1
  ; DEBUG: 16x14-tile 1bpp area highlighted in pale blue shades
  .byte     $1A,$2A,$20, $0F,$00,$10,$20
  .byte $0F,P0SHADE,$0F,P0SHADE, $0F,$0F,P1SHADE,P1SHADE
  .byte $0F,$1A,$2A,$20, $0F,$16,$26,$20
  .byte $0F,$00,$10,$20, $0F,$00,$10,$20

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

erase_border_stripes:
  .dbyt 0+32*0
  .byte (6-1)|NSTRIPE_DOWN
  .byte TILE_TLCORNER,TILE_VBAR,TILE_VBAR,TILE_VBAR,TILE_VBAR,TILE_BLCORNER
  .dbyt 20+32*0
  .byte (6-1)|NSTRIPE_DOWN
  .byte TILE_TRCORNER,TILE_VBAR,TILE_VBAR,TILE_VBAR,TILE_VBAR,TILE_BRCORNER
  .dbyt 19+32*0
  .byte 1-1
  .byte TILE_HBAR
  .repeat COIN_DESC_LINES, I
    .dbyt 1+32*(I+1)
    .byte (19-1)|NSTRIPE_RUN
    .byte TILE_BLANK
  .endrepeat
  .dbyt 1+32*(COIN_DESC_LINES+1)
  .byte (19-1)|NSTRIPE_RUN, TILE_HBAR
  .byte $FF

word_Stage:
  .byte "Stage", 0
