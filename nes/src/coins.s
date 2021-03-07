.include "nes.inc"
.include "global.inc"
.import bccwrap_forward  ; from unrom.s

coin_names:
  .addr coin_name01, coin_name02, coin_name03, coin_name04, coin_name05
  .addr coin_name06, coin_name07, coin_name08, coin_name09, coin_name10
  .addr coin_name11, coin_name12, coin_name13, coin_name14, coin_name15
  .addr coin_name16, coin_name17, coin_name18, coin_name19, coin_name20
  .addr coin_name21, coin_name22, coin_name23, coin_name24, coin_name25
  .addr coin_name26, coin_name27, coin_name28, coin_name29, coin_name30

coin_routines:
  .addr coin_01
  .addr coin_02
  .addr coin_03
  .addr coin_04
  .addr coin_05
  .addr coin_06
  .addr coin_07
  .addr coin_08
  .addr coin_09
  .addr coin_10

  .addr coin_11
  .addr coin_12
  .addr coin_13
  .addr coin_14
  .addr coin_15
  .addr coin_16
  .addr coin_17
  .addr coin_18
  .addr coin_19
  .addr coin_20

  .addr coin_21
  .addr coin_22
  .addr coin_23
  .addr coin_24
  .addr coin_25
  .addr coin_26
  .addr coin_27
  .addr coin_28
  .addr coin_29
  .addr coin_30

wait_vblank:
  lda nmis
  :
    cmp nmis
    beq :-
  rts

coin_name01:
  .byte "$2002 dummy read acks NMI",10
  .byte "ldx #$22 lda $20E0,x",10
  .byte "acknowledges NMI then",10
  .byte "reads bit 7 clear",0
coin_01:
  jsr wait_vblank
  ldx #$22
  lda $20E0,x  ; read $2002 then $2102 twice, first D7=1 then D7=0
  asl a        ; bit 7 clear: pass; bit 7 set: fail
  rts

coin_name02:
  .byte "APU frame counter status",10
  .byte "Within 1/60 s after $4017=0,",10
  .byte "$4015 D6 becomes 1",0
coin_02:
  ldy #0  ; suppress vblank interrupt
  sty PPUCTRL

  bit $4015  ; acknowledge irq
  sec
  bit $4015  ; if $4015 didn't ack it's fail
  bvs @earlyout

  sty $4017  ; reset the frame counter; enable frame IRQ
  ; wait long enough to get a length count
  ; 14915 APU cycles * 2/1284 iteration per APU cycle = 23.23
  ldx #32
  @loop:
    dey
    bne @loop
    dex
    bne @loop
  lda $4015  ; 7: DMC IRQ status; 6: APU status
  eor #$40   ; 1 is pass here; convert to 0 pass
  asl a
  asl a
@earlyout:
  rts

coin_name03:
  .byte "Coin #3",10
  .byte "Always pass for now",10
  .byte 34,"Old MacDonald had a farm,",10
  .byte "CLI SEI CLI SEI...",10
  .byte "oh wait, that's not it",34,0
coin_03:
  clc
  rts

coin_name04:
  .byte "Branch wrapping",10
  .byte "bcc from $FFxx to $00xx or",10
  .byte "vice versa wraps mod $10000",10
  .byte "(thanks blargg)",0
coin_04:
  ; Adapted from blargg's 02-branch_wrap.nes
  ; Load INX INX RTS RTS STP to $0000-$0002
  lda #$E8
  sta $00
  sta $01  ; BCC $10001 branches HERE
  lda #$60
  sta $02
  sta $03  ; 2021-03-05: no$nes overshoots when debugger disabled
  lda #$02
  sta $04  ; STP to drive the point home to no$nes users
  ldx #0
  clc
  jsr bccwrap_forward  ; if correct, X should be 1
  dex
  bne pass_if_x_zero

  ; Load BCC $FFE3 to $0000-$0001
  lda #$90
  sta $00
  lda #$E1
  sta $01
  jsr $0000
  dex
pass_if_x_zero:
  cpx #1
  rts

coin_name05:
  .byte "Hidden sprite is hidden",10
  .byte "Sprite at Y=$FF does not",10
  .byte "trigger sprite 0 hit",0
coin_05:
  lda #3
  jsr load_s0tiles

  ; place sprite 0 at Y=$FF
  lda #3
  sta OAM+0
  sta OAM+1
  sta OAM+2
  lda #$FF  ; Comment this out temporarily to make good emulators fail
  sta OAM+3
  jsr does_s0_hit
  cmp #$40
  rts

;;
; Loads the sprite 0 tiles, clears the tilemap to value A,
; and sets Y of sprite 1-63 to 240.
load_s0tiles:
  ldy #0
  ldx #$20
  jsr ppu_clear_nt
  stx PPUADDR
  stx PPUADDR
  lda #$F0
  ldx #4
  :
    sta OAM,x
    inx
    bne :-
  lda #>s0tiles_chr
  ldy #<s0tiles_chr
  ldx #8
  jmp unpb53_xtiles_ay

;;
; Waits for vblank, sets scroll (0, 0), pushes OAM
; No hit: A = $00, ZF = 1; hit: A = $40; ZF = 0
does_s0_hit:
  jsr wait_vblank
  bit PPUSTATUS
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  sta OAMADDR
  lda #>OAM
  sta OAM_DMA
  lda #VBLANK_NMI|OBJ_0000|BG_0000
  sta PPUCTRL
  lda #BG_ON|OBJ_ON
  sta PPUMASK
  ; wait out sprite 0 to avoid false alarms
  :
    bit PPUSTATUS
    bvs :-
  jsr wait_vblank
  lda PPUSTATUS
  and #$40
  rts

s0tiles_chr:
  .incbin "obj/nes/s0tiles.chr.pb53"

coin_name06:
  .byte "Sprite 0 flipping",10
  .byte "Flipped sprite still triggers",10
  .byte "sprite 0 hit",0
coin_06:
  jsr load_s0tiles
  ; Place a solid block at (128, 120) on the tilemap ($21F0)
  lda #$21
  sta PPUADDR
  lda #$F0
  sta PPUADDR
  ldx #$03
  stx PPUDATA

  ; and a sprite at (121, 113) such that its lower right pixel
  ; is within the solid block
  inx
  stx OAM+1
  lda #121
  sta OAM+3
  lda #112
  sta OAM+0

  ; 07 unflipped, 06 Hflipped, 05 Vflipped, and 04 HVflipped
  ; should all hit
  lda #$C0
  @loop:
    sta OAM+2
    jsr does_s0_hit
    sec
    beq @bail
    inc OAM+1  ; go to next tile
    ; No$nes also fails if this is changed to dec OAM+1
    lda OAM+2
    sbc #$40
    bcs @loop
  @bail:
  rts

coin_name07:
  .byte "Coin #7",10
  .byte "Always pass for now",0
coin_07:
  clc
  rts

coin_name08:
  .byte "Coin #8",10
  .byte "Always pass for now",0
coin_08:
  clc
  rts

coin_name09:
  .byte "Coin #9",10
  .byte "Always pass for now",0
coin_09:
  clc
  rts

coin_name10:
  .byte "Coin #10",10
  .byte "Always pass for now",10
  .byte 34,"Was that nocash",10
  .byte "or NoPass?",34,0
coin_10:
  clc
  rts

coin_name11:
  .byte "Coin #11",10
  .byte "Always pass for now",0
coin_11:
  clc
  rts

coin_name12:
  .byte "Coin #12",10
  .byte "Always pass for now",0
coin_12:
  clc
  rts

coin_name13:
  .byte "Coin #13",10
  .byte "Always pass for now",0
coin_13:
  clc
  rts

coin_name14:
  .byte "Coin #14",10
  .byte "Always pass for now",0
coin_14:
  clc
  rts

coin_name15:
  .byte "Coin #15",10
  .byte "Always pass for now",0
coin_15:
  clc
  rts

coin_name16:
  .byte "Coin #16",10
  .byte "Always pass for now",0
coin_16:
  clc
  rts

coin_name17:
  .byte "Coin #17",10
  .byte "Always pass for now",0
coin_17:
  clc
  rts

coin_name18:
  .byte "Coin #18",10
  .byte "Always pass for now",0
coin_18:
  clc
  rts

coin_name19:
  .byte "Coin #19",10
  .byte "Always pass for now",0
coin_19:
  clc
  rts

coin_name20:
  .byte "Coin #20",10
  .byte "Always pass for now",0
coin_20:
  clc
  rts

coin_name21:
  .byte "Coin #21",10
  .byte "Always pass for now",0
coin_21:
  clc
  rts

coin_name22:
  .byte "Coin #22",10
  .byte "Always pass for now",0
coin_22:
  clc
  rts

coin_name23:
  .byte "Coin #23",10
  .byte "Always pass for now",0
coin_23:
  clc
  rts

coin_name24:
  .byte "Coin #24",10
  .byte "Always pass for now",0
coin_24:
  clc
  rts

coin_name25:
  .byte "Coin #25",10
  .byte "Always pass for now",0
coin_25:
  clc
  rts

coin_name26:
  .byte "Coin #26",10
  .byte "Always pass for now",0
coin_26:
  clc
  rts

coin_name27:
  .byte "Coin #27",10
  .byte "Always pass for now",0
coin_27:
  clc
  rts

coin_name28:
  .byte "Coin #28",10
  .byte "Always pass for now",0
coin_28:
  clc
  rts

coin_name29:
  .byte "Coin #29",10
  .byte "Always pass for now",0
coin_29:
  clc
  rts

coin_name30:
  .byte "Coin #30",10
  .byte "Always pass for now",0
coin_30:
  clc
  rts
