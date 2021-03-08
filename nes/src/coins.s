.include "nes.inc"
.include "global.inc"
.include "mmc1.inc"
.import bccwrap_forward  ; from unrom.s

coin_names:
  .addr coin_name_stat_ack
  .addr coin_name_apufc_status
  .addr coin_name_apulc_status
  .addr coin_name_branch_bank
  .addr coin_name_s0_y255
  .addr coin_name_s0_flip
  .addr coin_name_9sprites_coarse
  .addr coin_name08, coin_name09, coin_name10
  .addr coin_name_ack_nmi
  .addr coin_name12, coin_name13
  .addr coin_name_branch_wrap
  .addr coin_name15
  .addr coin_name16, coin_name17, coin_name18, coin_name19, coin_name20
  .addr coin_name21, coin_name22, coin_name23, coin_name24, coin_name25
  .addr coin_name26, coin_name27, coin_name28, coin_name29, coin_name30

coin_routines:
  .addr coin_stat_ack
  .addr coin_apufc_status
  .addr coin_apulc_status
  .addr coin_branch_bank
  .addr coin_s0_y255
  .addr coin_s0_flip
  .addr coin_9sprites_coarse
  .addr coin_08
  .addr coin_09
  .addr coin_10

  .addr coin_ack_nmi
  .addr coin_12
  .addr coin_13
  .addr coin_branch_wrap
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

; Common routines ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

wait_vblank:
  lda nmis
  :
    cmp nmis
    beq :-
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

present_with_oam:
  jsr wait_vblank
  bit PPUSTATUS
  ldx #0
  ldy #0
  stx OAMADDR
  lda #>OAM
  sta OAM_DMA
  lda #VBLANK_NMI|OBJ_0000|BG_0000
  sec
  jmp ppu_screen_on

;;
; Waits for vblank, sets scroll (0, 0), pushes OAM
; No hit: A = $00, ZF = 1; hit: A = $40; ZF = 0
does_s0_hit:
  jsr present_with_oam

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

; Coins 1-10 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Intended to catch No$nes

coin_name_stat_ack:
  .byte "$2002 dummy read acks NMI",10
  .byte "ldx #$22 lda $20E0,x",10
  .byte "acknowledges NMI then",10
  .byte "reads bit 7 clear",0
coin_stat_ack:
  jsr wait_vblank
  ldx #$22
  lda $20E0,x  ; read $2002 then $2102 twice, first D7=1 then D7=0
  asl a        ; bit 7 clear: pass; bit 7 set: fail
  rts

coin_name_apufc_status:
  .byte "APU frame counter status",10
  .byte "Within 1/60 s after $4017=0,",10
  .byte "$4015 bit 6 becomes 1",0
coin_apufc_status:
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

coin_name_apulc_status:
  .byte "APU length counter status",10
  .byte "Within 0.1 s after $4017=$19,",10
  .byte "$4015 bit 0 goes 1 then 0",0
coin_apulc_status:
  lda #$40
  sta $4017
  lda #$0F
  sta $4015
  lda #$90  ; length counter not suppressed, silent software envelope
  sta $4000
  lda #$08
  sta $4001
  lda #$19
  sta $4003  ; set length 2/120 s
  lda $4015
  eor #$01
  lsr a
  bcs @have_c  ; after note, pulse 1 length ctr status becomes true
  ldx #54  ; 1789773 / (256*13*10) rounded up
  ldy #0
  @loop:
    lda $4015
    lsr a
    bcc @have_c
    iny
    bne @loop
    .assert >* = >@loop, error, "APU LC coin crosses bank boundary"
    dex
    bne @loop
@have_c:
  rts

.pushseg
; To protect the branch wrap test from crashing in PocketNES,
; test for other branch wrap behaviors first, such as the one
; that breaks The Magic of Scheherazade
.segment "BCCFROM00"
bccfrom00:
  @offset = bccto15 - (* + 1)
  .assert -128 <= @offset && @offset <= 127, error, "bccfrom00 out of bounds"
  .byte $90
  .byte <(bccto15 - (* + 1))
  inx
  inx
  rts

.segment "BCCTO00"
  sec
bccto00:
  sec
  sec
  rts

.segment "BCCTO01"
  sec
bccto01:
  sec
  sec
  rts

.segment "BCCTO02"
  sec
bccto02:
  sec
  sec
  rts

.segment "BCCTO15"
  inx
bccto15:
  inx
  clc
  rts

.popseg
coin_name_branch_bank:
  .byte "Branch to fixed bank",10
  .byte "bcc from $BFFx in bank 0",10
  .byte "lands in $C00x in last bank",10
  .byte 34,"Scheherazade had a",10
  .byte "thousand tales",34,0
coin_branch_bank:
  lda lastPRGBank
  pha
  lda #0
  jsr setPRGBank
  ldx #0
  clc
  jsr bccfrom00
  bcs @have_c
  dex
  cpx #1
@have_c:
  pla
  jmp setPRGBank

coin_name_s0_y255:
  .byte "Hidden sprite is hidden",10
  .byte "Sprite at Y=$FF does not",10
  .byte "trigger sprite 0 hit",0
coin_s0_y255:
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

coin_name_s0_flip:
  .byte "Sprite 0 flipping",10
  .byte "Flipped sprite triggers",10
  .byte "sprite 0 hit",0
coin_s0_flip:
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

;;
; Checks for 9 sprites
; @param A $00 for rendering off or $1E for rendering on
; @return A: Value after top row ($20 for seen or $00 for not);
; CF true if 9 sprites seen before top row or not seen after
; bottom row
two_rows_overflow_kernel:
  pha
  ; Wait for no sprite 0, no 9 sprites, no nothing
  jsr present_with_oam
  lda #%01100000
  :
    bit PPUSTATUS
    bne :-
  ; We're in the pre-render line
  ; Wait 32*105 cycles (just above the first sprite row on PAL)
  @wait1time = 32*105/5
  ldy #<-@wait1time
  ldx #>-@wait1time
  :
    iny
    bne :-
    inx
    bne :-
  .assert >* = >:-, error, "page crossing in two_rows_overflow_kernel"
  lda PPUSTATUS
  and #%00100000
  cmp #1
  pla  ; Have to get it off the stack
  bcs @bail

  ; Disable rendering if requested and wait for bottom of sprite row
  sta PPUMASK
  @wait2time = (45*341/3-32*105)/5
  ldy #<-@wait2time
  ldx #>-@wait2time
  :
    iny
    bne :-
    inx
    bne :-
  .assert >* = >:-, error, "page crossing in two_rows_overflow_kernel"
  lda PPUSTATUS
  and #%00100000
  pha  ; Stack: status below first row
  lda #BG_ON|OBJ_ON
  sta PPUMASK

  ; Wait for bottom of sprite row on NTSC
  @wait3time = (207-45)*341/3/5
  ldy #<-@wait3time
  ldx #>-@wait3time
  :
    iny
    bne :-
    inx
    bne :-
  .assert >* = >:-, error, "page crossing in two_rows_overflow_kernel"
  lda PPUSTATUS
  and #%00100000
  eor #%00100000  ; 0 if 9 sprites encountered; 1 if not
  cmp #1
  pla             ; $20 if first row seen; $00 if not
@bail:
  rts

coin_name_9sprites_coarse:
  .byte "Sprite overflow coarse time",10
  .byte "9 or more sprites on a line",10
  .byte "sets $2002 bit 5, provided",10
  .byte "rendering is on for that line",0
coin_9sprites_coarse:
  ; Clear all OAM first
  lda #$F0
  ldx #0
  :
    sta OAM,x
    inx
    bne :-
  ; Put 12 sprites on each of 2 lines.  Using 12 so we don't have
  ; to worry so much about corruption due to disabling rendering
  ; outside preroll time (X=320-340).
  ldx #(12 - 1)*4
  :
    lda #32
    sta OAM+0,x
    sta OAM+3,x
    lda #192
    sta OAM+12*4,x
    sta OAM+12*4+3,x
    dex
    dex
    dex
    dex
    bpl :-
  ; Ensure that sprite 0 or 9 sprites flag is true
  ; so that the next frame can detect the end of vblank
  jsr present_with_oam

  ; The first frame: Ensure 9 sprites detection occurs
  ; even if BG_ON is false
  lda #BG_ON
  jsr two_rows_overflow_kernel
  bcs @bail
  eor #%00100000
  bne @cmp1

  ; The second frame: Ensure turning off rendering before the first
  ; row and turning it back on after the second causes only the
  ; second to contribute to rendering
  lda #0
  jsr two_rows_overflow_kernel
  bcs @bail
@cmp1:
  cmp #1
@bail:
  rts

coin_name08:
  .byte "Coin #8",10
  .byte "Always pass for now",0
coin_08:
  clc
  rts

coin_name09:
  .byte "Coin #9",10
  .byte "Always pass for now",10
  .byte 34,"Old MacDonald had a farm,",10
  .byte "CLI SEI CLI SEI...",10
  .byte "oh wait, that's not it",34,0
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

coin_name_ack_nmi:
  .byte "$2002 read acks NMI",10
  .byte "Second $2002 read in vblank",10
  .byte "has bit 7 clear",10
  .byte "(Easier than #1)",0
coin_ack_nmi:
  jsr wait_vblank
  lda PPUSTATUS
  lda PPUSTATUS
  asl a
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

coin_name_branch_wrap:
  .byte "Branch wrapping",10
  .byte "bcc from $FFxx to $00xx or",10
  .byte "vice versa wraps mod $10000",10
  .byte "(thanks blargg)",0
coin_branch_wrap:
  ; Protect the test from PocketNES because PocketNES freezes on
  ; the forward test
  jsr coin_branch_bank
  bcs @have_c
  ; Protect the test from NESticle because NESticle freezes too
  jsr coin_ack_nmi
  bcs @have_c

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
  jsr bccwrap_forward  ; if correct, X should be 1
  dex
  bne @pass_if_x_zero

  ; Load BCC $FFE3 to $0000-$0001
  ; The backward test segfaults No$nes
  lda #$90
  sta $00
  lda #$E1
  sta $01
  jsr $0000
  dex
@pass_if_x_zero:
  cpx #1
@have_c:
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

; Coins 21-30 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Now it's starting to get tricky

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
