include "src/hardware.inc"

; the width of the area that can affect autotiling of onscreen tiles
def MAP_VICINITY_WIDTH_MT equ 16
def MAP_COLUMN_HEIGHT_MT equ 16

def COINCELS_BASE_TILE equ $7B

section "tilemapcol", WRAM0
wMapCol: ds MAP_COLUMN_HEIGHT_MT

section "mapdecodestate", WRAM0, ALIGN[1]
; A map consists of a bitmap and contents.  The bitmap is an array
; of up to 256 u16 values, each representing one column, where a
; 1 bit in a particular position means the metatile there differs
; from the predicted metatile.  The contents represent the (nonzero)
; metatile that replaces each predicted metatile.

wCameraY: ds 1
wCameraX: ds 2         ; pixel position (1/16 column) of camera
wMapVicinityLeft: ds 1 ; left column of valid area of sliding window
wMapFetchedX: ds 1     ; Column corresponding to wMapCol
wMapDecodeX: ds 1      ; Column corresponding to wMapContentsPtr
wMapBitmapBase: ds 2   ; Pointer to the base of a map's bitmap
wMapContentsPtr: ds 2  ; Pointer to contents at column wMapDecodeX

def TEST_REWIND_COLUMN equ 4

section "stack", WRAM0, ALIGN[1]
wStackTop: ds 64
wStackStart:

section "main", ROM0

main:
  ld hl, level1chr_2b
  ld de, $9000
  call memcpy_pascal16
  ld hl, coincels_2b
  ld de, $8000 + 16 * COINCELS_BASE_TILE
  call memcpy_pascal16

  ; Set up initial map pointer
  ld hl, wCameraY
  ld a, 28
  ld [hl+], a
  assert wCameraX == wCameraY + 1
  ld a, 10
  ld [hl+], a
  xor a
  ld [hl+], a
  assert wMapVicinityLeft == wCameraX + 2
  ld [hl], a
  ld hl, wMapDecodeX
  ld [hl+], a
  assert wMapBitmapBase == wMapDecodeX + 1
  ld a, low(level1Bitmap)
  ld [hl+], a
  ld a, high(level1Bitmap)
  ld [hl+], a
  assert wMapContentsPtr == wMapBitmapBase + 2
  ld a, low(level1Contents)
  ld [hl+], a
  ld a, high(level1Contents)
  ld [hl+], a

  ld hl, wMapVicinity
  call redraw_whole_screen
  xor a
  ldh [rIF], a
  ld a, IEF_VBLANK
  ldh [rIE], a
  ei

forever:
  call read_pad
  call move_camera
  xor a
  ld [wOAMUsed], a
  call draw_coins
  call lcd_clear_oam

  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_OBJON|LCDCF_BG9800|LCDCF_BG8800
  ldh [rLCDC], a

  halt
  call run_dma
  ld a, %11100100
  ldh [rBGP], a
  ldh [rOBP1], a
  ld a, [wCameraX]
  ldh [rSCX], a
  ld a, [wCameraY]
  ldh [rSCY], a
  jr forever

; Camera control ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def CAM_X_MAX equ 4096 - SCRN_X

move_camera:
  ldh a, [hCurKeys]
  ld b, a
  ld a, [wCameraY]
  bit PADB_DOWN, b
  jr z, .notDown
    inc a
  .notDown:
  bit PADB_UP, b
  jr z, .notUp
    dec a
  .notUp:
  cp 256-SCRN_Y
  jr nc, .noWriteY
    ld [wCameraY], a
  .noWriteY:

  ld hl, wCameraX
  ld e, [hl]
  inc hl
  ld d, [hl]
  bit PADB_RIGHT, b
  jr z, .notRight
    inc de
  .notRight:
  bit PADB_LEFT, b
  jr z, .notLeft
    dec de
  .notLeft:
  ld a, e
  cp low(CAM_X_MAX)
  ld a, d
  sbc high(CAM_X_MAX)
  jr nc, .noWriteX
    ld [hl], d
    dec hl
    ld [hl], e
  .noWriteX:

  ; Move map vicinity toward camera X
  ld hl, wCameraX
  ld a, [hl+]
  ld h, [hl]
  ld l, a
  add hl, hl
  add hl, hl
  add hl, hl
  add hl, hl  ; H = camera X in map columns

  ld a, h  ; A = camera X in map columns
  ld hl, wMapVicinityLeft
  sub [hl]

  ; A is distance in whole metatiles from left edge of vicinity to
  ; left edge of camera
  ; [HL] is still 
  ; <0 (CF=1): go left now
  ; 0: go left unless already 0
  ; >=MAP_VICINITY_WIDTH_MT-SCRN_X/16-1: go right unless at 240
  ;   already 256-MAP_VICINITY_WIDTH_MT
  jr c, .decode_to_left
  jr z, .decode_to_left
  cp MAP_VICINITY_WIDTH_MT-SCRN_X/16-1
  ret c

    ; Decode to right
    ld a, [hl]
    add MAP_VICINITY_WIDTH_MT
    ret c  ; do nothing if already at right side
    inc [hl]
    call map_seek_column_a
    call map_fetch_bitmap_column
    call map_fetch_col_forward
    call map_decode_markov
    call map_stash_decoded_col
    
    ; and draw them to the tilemap
    ld hl, wMapFetchedX
    ld a, 255
    cp [hl]  ; CF=1 if at far right
    ld a, 1
    adc a
    ld c, a  ; 3 columns at far right, 2 columns elsewhere
    ld a, [hl]
    add a
    dec a  ; Draw starting at right half of column to left of decoded
    ld b, a
    jp blit_c_columns
  .decode_to_left:
    ld a, [hl]
    or a
    ret z  ; do nothing if already at left side
    call map_seek_column_a
    call map_fetch_prev_bitmap_column
    call map_fetch_col_backward
    call map_decode_markov
    call map_stash_decoded_col

    ; and draw them to the tilemap
    ld hl, wMapFetchedX
    ld a, [hl]
    ld [wMapVicinityLeft], a
    ; draw columns 1 and 2, and draw column 0 if at far left
    cp 1     ; CF=1 if at far left
    ld a, 1
    adc a
    ld c, a  ; 3 columns at far left, 2 columns elsewhere
    rra
    ccf      ; CF=0 if at far left
    ld a, [hl]
    adc a
    ld b, a
    jp blit_c_columns

if 0
debug_print_de:
  ld d, d
  jr .txtend
    dw $6464
    dw $0000
    db "DE=%DE%;CF=%CARRY%"
  .txtend:
  ret
endc

redraw_whole_screen:
  ld a, [wMapVicinityLeft]
  call map_seek_column_a
  ld b, MAP_VICINITY_WIDTH_MT
  .decodeloop:
    push bc
    call map_fetch_bitmap_column
    call map_fetch_col_forward
    call map_decode_markov
    call map_stash_decoded_col
    pop bc
    dec b
    jr nz, .decodeloop

  ; The leftmost column is valid only if camera is at the far left.
  ld a, [wMapVicinityLeft]
  cp 1     ; CF = 1: at far left; 0: at next column
  ld a, MAP_VICINITY_WIDTH_MT - 1
  adc a
  ld c, a  ; C = number of columns to draw
  rra
  ccf      ; CF = 0: at far left; 1: at next column
  ld a, [wMapVicinityLeft]
  adc a
  ld b, a  ; B = starting column
  ; Fall through to B columns

;;
; Draws tile columns from vicinity to the screen.
; @param C count of tilemap columns (half vicinity columns)
; @param B first tilemap column to draw (0-31)
blit_c_columns:
  .drawloop:
    push bc
    ld a, b
    call blit_one_col
    pop bc
    inc b
    dec c
    jr nz, .drawloop
  ret

; map decoding ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Seeks to a column of the map.
; @param wMapDecodeX current column number
; @param A target column number 
; @return wMapDecodeX equal to initial A; wMapContentsPtr adjusted
; by the size of skipped contents
map_seek_column_a:
  ld hl, wMapDecodeX
  sub [hl]
  ; A = number of forward steps to take modulo 256
  ; CF = true if negative
  ret z
  push af
  call map_fetch_bitmap_column
  ld a, [wMapContentsPtr+0]
  ld e, a
  ld a, [wMapContentsPtr+1]
  ld d, a
  ; HL points to bitmap column; DE points to contents
  pop af
  ld b, a
  jr c, .seek_backward
  .seek_forward:
    ld a, [wMapDecodeX]
    add b
    ld [wMapDecodeX], a
  .seek_forward_loop:
    ; take B steps forward
    ld a, [hl+]
    call add_de_popcnt_a
    ld a, [hl+]
    call add_de_popcnt_a
    dec b
    jr nz, .seek_forward_loop
  .writeback_de:
    ld a, e
    ld [wMapContentsPtr+0], a
    ld a, d
    ld [wMapContentsPtr+1], a
    ret
  .seek_backward:
    ld a, [wMapDecodeX]
    add b
    ld [wMapDecodeX], a
  .seek_backward_loop:
    ; take 256-B steps backward
    dec hl
    ld a, [hl-]
    call sub_de_popcnt_a
    ld a, [hl]
    call sub_de_popcnt_a
    inc b
    jr nz, .seek_backward_loop
    jr .writeback_de

add_de_popcnt_a:
  add a
  jr nc, .no_add
    inc de
    or a
  .no_add:
  jr nz, add_de_popcnt_a
  ret

sub_de_popcnt_a:
  add a
  jr nc, .no_add
    dec de
    or a
  .no_add:
  jr nz, sub_de_popcnt_a
  ret

;;
; Fetches a column from the overrides bitmap at X = wMapDecodeX
; @param wMapDecodeX index into wMapBitmapBase
; @return BC: list of bits to replace; HL: pointer to bitmap column
map_fetch_bitmap_column:
  ld hl, wMapDecodeX
  ld a, [hl+]
.have_col_a:
  ld e, a
  ld d, 0      ; DE = map decode X position
  assert wMapBitmapBase == wMapDecodeX + 1
  ld a, [hl+]
  ld h, [hl]
  ld l, a      ; HL = base of map's Markov overrides bitmap
  add hl, de
  add hl, de   ; HL = address of current column of overrides bitmap
  ld a, [hl+]
  ld c, a
  ld a, [hl-]
  ld b, a      ; BC = column of overrides bitmap
  ret

;;
; Fetches a column from the overrides bitmap at X = wMapDecodeX-1
map_fetch_prev_bitmap_column:
  ld hl, wMapDecodeX
  ld a, [hl+]
  dec a
  jr map_fetch_bitmap_column.have_col_a

;;
; Decodes one column of map metatile overrides from wMapContentsPtr
; to wMapCol.  If wMapDecodeX isn't already $FF, it is incremented
; and the end address is written back to wMapContentsPtr.
; @param BC bitmap column
map_fetch_col_forward:
  ld hl, wMapContentsPtr
  ld a, [hl+]
  ld h, [hl]
  ld l, a
  ld de, wMapCol
  .fetchloop:
    xor a
    sla c
    rl b
    jr nc, .skip_map_fetch
      ld a, [hl+]
    .skip_map_fetch:
    ld [de], a
    inc de
    ld a, e
    xor low(wMapCol + MAP_COLUMN_HEIGHT_MT)
    jr nz, .fetchloop

  ld a, [wMapDecodeX]
  ld [wMapFetchedX], a
  inc a
  ret z
  ld [wMapDecodeX], a
  ld a, l
  ld [wMapContentsPtr+0], a
  ld a, h
  ld [wMapContentsPtr+1], a
  ret

map_fetch_col_backward:
  ld a, [wMapDecodeX]
  dec a
  ld [wMapFetchedX], a
  ld [wMapDecodeX], a
  ld hl, wMapContentsPtr
  ld a, [hl+]
  ld h, [hl]
  ld l, a
  dec hl
  ld de, wMapCol + MAP_COLUMN_HEIGHT_MT - 1
  .fetchloop:
    xor a
    srl b
    rr c
    jr nc, .skip_map_fetch
      ld a, [hl-]
    .skip_map_fetch:
    ld [de], a
    dec de
    ld a, e
    xor low(wMapCol - 1)
    jr nz, .fetchloop
  inc hl
  ld a, l
  ld [wMapContentsPtr+0], a
  ld a, h
  ld [wMapContentsPtr+1], a
  ret

map_decode_markov:
  ld hl, wMapCol
  ld b, 16
  .markovloop:
    ld a, [hl]
    or a
    jr nz, .skip_markov
      ld a, c
      add low(mt_next)
      ld e, a
      adc high(mt_next)
      sub e
      ld d, a
      ld a, [de]
    .skip_markov:
    ld [hl+], a
    ld c, a
    dec b
    jr nz, .markovloop
  ret

map_stash_decoded_col:
  ld a, [wMapFetchedX]
  and $0F
  ld de, wMapVicinity
  add d
  ld d, a
  ld hl, wMapCol
  ld bc, MAP_COLUMN_HEIGHT_MT
  jp memcpy

;;
; Draws wMapCol to tilemap at wMapFetchedX
; @param A column to draw (0-31)
blit_one_col:
  ld bc, wMapVicinity
  ld d, high(_SCRN0)
  and $1F
  ld e, a  ; DE: pointer into destination tilemap
  rra
  add b
  ld b, a  ; BC: pointer into vicinity (metatile IDs)
           ; B: X position; C: Y position
  .blkloop:
    ; find metatile definition
    ld a, e
    rra  ; CF = E bit 0, selecting left or right half
    ld h, 0
    ld a, [bc]
    rla
    rl h
    rla
    rl h
    add low(metatile_defs)
    ld l, a
    ld a, h
    adc high(metatile_defs)
    ld h, a

    ; wait for mode 0 or 1
    .stat01loop:
      ldh a, [rSTAT]
      and STATF_BUSY
      jr nz, .stat01loop
    ; write it to VRAM
    ld a, [hl+]  ; top left
    ld [de], a
    set 5, e
    ld a, [hl]  ; bottom left
    ld [de], a
    ld a, e
    add 32
    ld e, a
    adc d
    sub e
    ld d, a
    inc bc
    bit 2, d
    jr z, .blkloop
  ret

; Test level data ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; stage 1

def MT_GROUND equ 1
def MT_GROUND_0HT equ 32
def MT_CAVE equ 33
def MT_LADDER equ 3
def MT_SIGN equ 6
def MT_WARNING_SIGN equ 7
def MT_BUSHL equ 8
def MT_BUSHR equ 9
def MT_CLOUDL equ 12
def MT_CLOUDC equ 13
def MT_CLOUDR equ 14
def MT_SMBUSH equ 15
def MT_FLOWER1 equ 16
def MT_FLOWER2 equ 17
def MT_FLOWER3 equ 18
def MT_TALL_FLOWER equ 19
def MT_TREEL equ 22  ; these go under a BUSHL and BUSHR
def MT_TREER equ 23
def MT_BRIDGE_RAIL equ 28
def MT_BRIDGEL equ 29
def MT_BRIDGER equ 31

section "leveldata", ROM0
level1Bitmap:
dw %0000000010000000
dw %0000000010000000
dw %0000000010000000
dw %0000000010000000
dw %0000000010000000
dw %0000000010000000
dw %0001000100000000
dw %0001000010000000  ; Gravity barrier

dw %0001000000100000
dw %0000000000100000
dw %0000000001000000
dw %0000000000100000
dw %0000000001000000
dw %0000000000100000
dw %0000000001000000
dw %0000000000100000

dw %0000000001000000
dw %0000000010000000
dw %0000000001000000
dw %0000000100000000
dw %0000000100000000
dw %0000000001000000
dw %0000000001000000
dw %0000000010000000

dw %0000000001000000
dw %0000001001000000
dw %0000001001000000
dw %0000011001000000
dw %0000011001000000
dw %0000011001000000
dw %0000011010000000
dw %0000010001000000

dw %0000010000000000
dw %0000011000000000
dw %0000010000000000
dw %0001000000000000
dw %0110010010001000
dw %0110010010001000
dw %0000010010001000
dw %0000010010001000

dw %0000000000001000
dw %0000000000001000
dw %0000000000000000
dw %0000000000000000
dw %0000000000000000
dw %0000000000000000
dw %0000000000000000
dw %0000000000000000

dw %0000000000000000
dw %0000000000000000
dw %0000000000000000
dw %0000000000000000
dw %0000000010000000
dw %0000000010000000
dw %0000000010000000
dw %0000000010000000

dw %0000000010000000
dw %0000000010000000
dw %0000000010000000
dw %0000000010000000
dw %0000001000000000
dw %0000001000000000
dw %0000001000000000
dw %0000001000000000

level1Contents:
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_CLOUDL, MT_SIGN
db MT_CLOUDC, MT_GROUND

db MT_CLOUDR, MT_GROUND
db MT_GROUND
db MT_FLOWER1
db MT_GROUND
db MT_FLOWER2
db MT_GROUND
db MT_SIGN
db MT_GROUND

db MT_GROUND
db MT_SMBUSH
db MT_GROUND
db MT_BUSHL
db MT_BUSHR
db MT_GROUND
db MT_GROUND
db MT_FLOWER3

db MT_GROUND
db MT_LADDER, MT_GROUND
db MT_GROUND_0HT, MT_GROUND
db MT_BUSHL, MT_GROUND_0HT, MT_GROUND
db MT_BUSHR, MT_GROUND_0HT, MT_GROUND
db MT_SIGN, MT_GROUND_0HT, MT_GROUND
db MT_BRIDGE_RAIL, MT_BRIDGEL, MT_WARNING_SIGN
db MT_BRIDGE_RAIL, MT_GROUND

db MT_BRIDGE_RAIL
db MT_BRIDGE_RAIL, MT_BRIDGER
db MT_GROUND
db MT_TALL_FLOWER
db MT_BUSHL, MT_TREEL, MT_GROUND, MT_CAVE, MT_GROUND
db MT_BUSHR, MT_TREER, MT_GROUND, MT_CAVE, MT_GROUND
db MT_GROUND, MT_CAVE, MT_GROUND
db MT_GROUND, MT_CAVE, MT_GROUND

db MT_GROUND
db MT_GROUND
; none
; none
; none
; none
; none
; none

; none
; none
; none
; none
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND

db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND


mt_next:
  db 0, 2, 2, 4, 4, 0, 1, 1
  db 10, 11, 1, 1, 0, 0, 0, 1
  db 1, 1, 1, 20, 1, 0, 24, 25
  db 26, 27, 1, 1, 30, 0, 0, 0
  db 33, 33

section "metatile_defs", ROM0, align[3]
metatile_defs:
  ;  /X \/  \/ X\/  \
  ;  \  /\X /\  /\ X/
  db $00,$00,$00,$00  ; sky
  db $4E,$03,$4D,$03  ; ground top
  db $03,$03,$03,$03  ; ground inside
  db $08,$18,$09,$19  ; ladder top
  db $18,$18,$19,$19  ; ladder inside
  db $00,$00,$00,$00
  db $0A,$1A,$0B,$1B  ; sign
  db $2A,$3A,$2B,$3B  ; ! sign

  db $10,$20,$11,$21  ; bushtl
  db $12,$22,$13,$23  ; bushtr
  db $30,$0C,$31,$03  ; bushbl
  db $32,$03,$33,$0F  ; bushbr
  db $00,$00,$04,$14  ; cloudL
  db $05,$15,$06,$16  ; cloudC
  db $07,$17,$00,$00  ; cloudR
  db $28,$38,$29,$39  ; smbush

  db $00,$00,$46,$3F  ; flower1
  db $00,$00,$47,$3F  ; flower2
  db $00,$00,$2F,$3F  ; flower3
  db $00,$00,$2C,$3F  ; flower4 top
  db $00,$00,$3C,$3F  ; flower4 extended
  db $00,$00,$00,$00
  db $30,$0C,$31,$0D  ; treetop_bl
  db $32,$0E,$33,$0F  ; treetop_br

  db $1C,$00,$1D,$2D  ; treetrunk_tl
  db $1E,$2E,$1F,$00  ; treetrunk_tr
  db $00,$00,$2D,$3D  ; treetrunk_bl
  db $2E,$3E,$00,$00  ; treetrunk_br
  db $00,$35,$00,$35  ; bridge rail
  db $24,$34,$25,$00  ; bridge left
  db $36,$00,$36,$00  ; bridge middle
  db $26,$00,$27,$37  ; bridge bottom

  db $4E,$02,$4D,$02  ; 0ht top
  db $01,$02,$02,$01  ; 0ht inside

coin_pos: 
  db 15, 9
  db 24, 8
  db 27, 5
  db 38, 4
  db 36, 11
def NUM_DEFINED_COINS equ (@-coin_pos)/2

sign_pos:
  db 6, 7
  db 14, 9
  db 30, 8
  db 29, 5
def NUM_DEFINED_SIGNS equ (@-sign_pos)/2

section "bgchr", ROMX, BANK[1]

level1chr_2b:
  dw .end-.start
.start:
  incbin "obj/gb/level1chr.2b"
.end:
coincels_2b:
  dw .end-.start
.start:
  incbin "obj/gb/coincels.2b"
.end:

; Static sprite drawing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def COINS_ATTR equ $91  ; no flip, DMG and GBC palette 1

section "draw_coin", ROM0
draw_coins:
  ld bc, coin_pos
  ld de, wOAMUsed
  ld a, [de]
  ld e, a
  .coinloop:
    ld a, [bc]
    inc bc
    push bc

    ; calculate X coordinate of coin
    ld hl, wCameraX
    ld c, [hl]
    inc hl
    ld b, [hl]
    ld l, a
    ld h, 0
    add hl, hl
    ; add 12 (GB sprite offset 8 plus 4 from left) to center object
    ; in metatile
    inc l
    add hl, hl
    inc l
    add hl, hl
    add hl, hl
    ld a, l
    sub c
    ld l, a
    ld a, h
    sbc b
    pop bc
    jr nz, .not_this_coin
    ld a, l
    cp SCRN_X+8
    jr nc, .not_this_coin

    ; calculate Y coordinate of coin
    ld a, [wCameraY]
    ld h, a
    ld a, [bc]
    inc a  ; draw coin at top of metatile (offset 16)
    add a
    add a
    add a
    add a
    sub h
    jr c, .not_this_coin
    cp SCRN_Y+16
    jr nc, .not_this_coin

      ld [de], a
      inc e
      ld a, l
      ld [de], a
      inc e
      ldh a, [hVblanks]
      and $38
      rra
      rra
      rra
      cp 5
      jr c, .coin_not_reverse
        cpl
        add 8+1
      .coin_not_reverse:
      add COINCELS_BASE_TILE
      ld [de], a
      inc e
      ld a, COINS_ATTR
      ld [de], a
      inc e
    .not_this_coin:
    inc bc
    ld a, c
    xor low(coin_pos + NUM_DEFINED_COINS * 2)
    jr nz, .coinloop
  ld a, e
  ld [wOAMUsed], a
  ret


; Administrative stuff ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "Shadow OAM", WRAM0, ALIGN[8]
wShadowOAM: ds 160
wOAMUsed: ds 1

section "PPU various variables", HRAM
hVblanks: ds 1

section "header", ROM0[$100]
  nop
  jp init
  ds 76, $00
init:
  di
  ld sp, wStackStart
  call lcd_off
  ld a, $FF
  ldh [hCurKeys], a
  ld hl, hramcode_LOAD
  ld de, hramcode_RUN
  call memcpy_pascal16
  xor a
  ldh [hVblanks], a
  ld hl, wShadowOAM
  ld c, 160
  rst memset_tiny
  call run_dma
  jp main

section "vblank_isr", ROM0[$40]
  push af
  ld a, [hVblanks]
  inc a
  ldh [hVblanks], a
  pop af
  reti

section "ppuclear", ROM0
;;
; Waits for forced blank (rLCDC bit 7 clear) or vertical blank
; (rLY >= 144).  Use before VRAM upload or before clearing rLCDC bit 7.
busy_wait_vblank::
  ; If rLCDC bit 7 already clear, we're already in forced blanking
  ldh a,[rLCDC]
  rlca
  ret nc

  ; Otherwise, wait for LY to become 144 through 152.
  ; Most of line 153 is prerender, during which LY reads back as 0.
.wait:
  ldh a, [rLY]
  cp 144
  jr c, .wait
  ret

lcd_off::
  call busy_wait_vblank

  ; Use a RMW instruction to turn off only bit 7
  ld hl, rLCDC
  res 7, [hl]
  ret

;;
; Moves sprites in the display list from wShadowOAM+[wOAMUsed]
; through wShadowOAM+$9C offscreen by setting their Y coordinate to
; 0, which is completely above the screen top (16).
lcd_clear_oam::
  ; Destination address in shadow OAM
  ld hl, wOAMUsed
  ld a, [hl]
  and $FC
  ld l,a

  ; iteration count
  rrca
  rrca
  add 256 - 40
  ld c,a

  xor a
.rowloop:
  ld [hl+],a
  inc l
  inc l
  inc l
  inc c
  jr nz, .rowloop
  ret

section "memset_tiny",ROM0[$08]
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

section "memcpy", ROM0
;;
; Copy a string preceded by a 2-byte length from HL to DE.
; @param HL source address
; @param DE destination address
memcpy_pascal16::
  ld a, [hl+]
  ld c, a
  ld a, [hl+]
  ld b, a
  ; fall through to memcpy

;;
; Copies BC bytes from HL to DE.
; @return A: last byte copied; HL at end of source;
; DE at end of destination; B=C=0
memcpy::
  ; Increment B if C is nonzero
  dec bc
  inc b
  inc c
.loop:
  ld a, [hl+]
  ld [de],a
  inc de
  dec c
  jr nz,.loop
  dec b
  jr nz,.loop
  ret

section "HRAMCODE_src", ROM0
;;
; While OAM DMA is running, the CPU keeps fetching instructions
; while ROM and WRAM are inaccessible.  A program needs to jump to
; HRAM and busy-wait 160 cycles until OAM DMA finishes.
hramcode_LOAD:
  dw hramcode_RUN_end-hramcode_RUN
load "HRAMCODE", HRAM
hramcode_RUN:

;;
; Copy a display list from shadow OAM to OAM
; @param HL address to read once while copying is in progress
; @return A = value read from [HL]
run_dma::
  ld a, wShadowOAM >> 8
  ldh [rDMA],a
  ld b, 40
.loop:
  dec b
  jr nz,.loop
  ret

hramcode_RUN_end:
endl
