include "src/hardware.inc"
include "src/global.inc"

def COINCELS_BASE_TILE equ $7B

; This number is added to wGlobalSubpixel every frame.  It must be
; odd and should be close to 256 divided by a highly irrational
; number (lots of small terms in continued fraction representation)
; to mask repetition.  Here we use 256 divided by the golden ratio,
; which is the most irrational number (see numberphile video).
def GLOBAL_SUBPIXEL_ADD equ 159
def STARTING_CURSOR_Y equ 64
def STARTING_CURSOR_X equ 64

def NUM_HIDDEN_OBJS equ 10
def PAGE_MINDY equ 9
def PAGE_FOUND_THEM_ALL equ 10
def PAGE_INSTRUCTIONS equ 11
export PAGE_INSTRUCTIONS

section "tilemapcol", WRAM0
wMapCol: ds MAP_COLUMN_HEIGHT_MT

section "mapdecodestate", WRAM0, ALIGN[1]
; A map consists of a bitmap and contents.  The bitmap is an array
; of up to 256 u16 values, each representing one column, where a
; 1 bit in a particular position means the metatile there differs
; from the predicted metatile.  The contents represent the (nonzero)
; metatile that replaces each predicted metatile.

wCameraY:: ds 1
wCameraX:: ds 2         ; pixel position (1/16 column) of camera
wMapVicinityLeft:: ds 1 ; left column of valid area of sliding window
wMapFetchedX: ds 1      ; Column corresponding to wMapCol
wMapDecodeX: ds 1       ; Column corresponding to wMapContentsPtr
wMapBitmapBase: ds 2    ; Pointer to the base of a map's bitmap
wMapContentsPtr: ds 2   ; Pointer to contents at column wMapDecodeX

wGlobalSubpixel: ds 1
wCursorY: ds 1
wCursorX: ds 2
wCursorYAdd: ds 1
wCursorXAdd: ds 1

wCursorItem: ds 1

section "seenpages", WRAM0
wSeenPages: ds NUM_HIDDEN_OBJS

def TEST_REWIND_COLUMN equ 4

section "main", ROM0

main::
  call show_title
  call clear_gbc_attr
  ld de, static_tiles
  call pb16_unpack_dest_length_block
  call pb16_unpack_dest_length_block
  call pb16_unpack_dest_length_block

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

  assert wGlobalSubpixel == wMapContentsPtr + 2
  xor a
  ld [hl+], a
  assert wCursorY == wGlobalSubpixel + 1
  ld a, STARTING_CURSOR_Y
  ld [hl+], a
  assert wCursorX == wCursorY + 1
  ld a, low(STARTING_CURSOR_X)
  ld [hl+], a
  ld a, high(STARTING_CURSOR_X)
  ld [hl+], a
  xor a
  assert wCursorYAdd == wCursorX + 2
  ld [hl+], a
  ld [hl+], a
  ld hl, wSeenPages
  ld c, NUM_HIDDEN_OBJS
  rst memset_tiny

  call mindy_init
  call textwindow_init
  ld hl, wMapVicinity
  call redraw_whole_screen
  xor a
  ldh [rIF], a
  ld a, IEF_VBLANK
  ldh [rIE], a
  ei

  ld a, 7
  ldh [rWX], a
  ld a, FRAME_Mindy_walk1
  call mindy_set_cel_A

  ld a, %11100100
  ldh [rBGP], a
  ld hl, metatiles_palettes
  lb bc, MT_NUM_PALETTES * 8, low(rBCPS)
  ld a, $80
  call set_gbc_palette

.forever:
  ld hl, wGlobalSubpixel
  ld a, GLOBAL_SUBPIXEL_ADD
  add [hl]
  ld [hl], a
  call read_pad
  call move_cursor
  call move_camera
  call textwindow_update
  xor a
  ld [wOAMUsed], a
  call draw_cursor
  call draw_coins
  call mindy_draw_current_cel
  call lcd_clear_oam

  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_WINON|LCDCF_OBJON|LCDCF_WIN9C00|LCDCF_BG9800|LCDCF_BG8800
  ldh [rLCDC], a

  halt
  call run_dma
  ld a, %11100100
  call set_obp1
  ld a, [hVblanks]
  rra
  sbc a
  and %00010000
  or  %10000000
  call set_obp0
  ld a, [wCameraX]
  ldh [rSCX], a
  ld a, [wCameraY]
  ldh [rSCY], a
  ld a, [wWindowProgress]
  sub TEXTWINDOW_ROWS
  add a  ; CF true to hide window
  sbc a
  or SCRN_Y-TEXTWINDOW_ROWS * 8
  ld [rWY], a
  jr .forever

; Selection control ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def CURSOR_TILE_NO_MATCH equ $70
def CURSOR_PIXELS_PER_PRESS equ 8
def MINDY_HITBOX_WIDTH equ 20

move_cursor:
  ld a, $FF
  ld [wCursorItem], a

  ; 1. control what to add
  ld b, PADF_UP|PADF_DOWN|PADF_LEFT|PADF_RIGHT
  call autorepeat
  ldh a, [hNewKeys]
  ld b, a
  and PADF_UP|PADF_DOWN|PADF_LEFT|PADF_RIGHT
  jr z, .no_cursor_movement
    ; check for individual directions
    ld a, [wCursorYAdd]
    bit PADB_DOWN, b
    jr z, .notDown
      add CURSOR_PIXELS_PER_PRESS
    .notDown:
    bit PADB_UP, b
    jr z, .notUp
      sub CURSOR_PIXELS_PER_PRESS
    .notUp:
    ld [wCursorYAdd], a
    ld a, [wCursorXAdd]
    bit PADB_RIGHT, b
    jr z, .notRight
      add CURSOR_PIXELS_PER_PRESS
    .notRight:
    bit PADB_LEFT, b
    jr z, .notLeft
      sub CURSOR_PIXELS_PER_PRESS
    .notLeft:
    ld [wCursorXAdd], a

    ; Moving the cursor shows the win notice if won;
    ; otherwise it closes the window.
    ld hl, wSeenPages
    .seenloop:
      ld a, [hl+]
      or a
      jr z, .not_won_msg
      ld a, l
      xor low(wSeenPages + NUM_HIDDEN_OBJS)
      jr nz, .seenloop
    ld a, PAGE_FOUND_THEM_ALL
    call textwindow_start_page
    jr .no_cursor_movement
  .not_won_msg:
    ld a, $FF
    ld [wWindowProgress], a
  .no_cursor_movement:

  ldh a, [hNewKeys]
  bit PADB_SELECT, a
  call nz, mindy_set_next_cel

  ; 2. move the cursor itself
  ld hl, wCursorYAdd
  ld b, [hl]
  call divide_B_by_damping
  ld c, a     ; C: distance to move cursor
  ld a, [hl]  ; log these pixels as being used up
  sub c
  ld [hl], a
  ld hl, wCursorY
  ld a, [hl]
  ld b, a     ; B: previous position
  add c
  ld d, a     ; D: new position
  ; check for wraparound based on carry from D-B
  sub b       ; CF: 1 if D>=B
  rra         ; A bit 7: 1 if D >= B
  xor c       ; A bit 7: 1 if wrapped
  add a
  jr nc, .have_Y_in_D
    ld a, b
    add a  ; CF: sign of old position
    sbc a  ; A: 0 if was in top half or FF in bottom half
    and 255 - 255 % CURSOR_PIXELS_PER_PRESS
    ld d, a
  .have_Y_in_D:
  ld [hl], d

  ld hl, wCursorXAdd
  ld b, [hl]
  call divide_B_by_damping
  ld c, a
  add a
  sbc a
  ld b, a     ; BC: 16-bit distance to move cursor
  ld a, [hl]  ; log these pixels as being used up
  sub c
  ld [hl], a

  ld hl, wCursorX
  ld a, c
  add [hl]
  ld [hl+], a
  ld a, b
  adc [hl]
  cp MAP_WIDTH_MT / 16
  jr c, .have_X_hi_in_A
    ; bit 7 set if off left, or clear if off right
    add a
    ccf      ; CF clear if at left, or set if off right
    sbc a
    ld b, a  ; B = $FF at right, 0 at left
    xor a
    ld [wCursorXAdd], a
    dec hl
    ld a, 255 - 255 % CURSOR_PIXELS_PER_PRESS - CURSOR_PIXELS_PER_PRESS
    and b
    add CURSOR_PIXELS_PER_PRESS
    ld [hl+], a
    ld a, MAP_WIDTH_MT / 16 - 1
    and b
  .have_X_hi_in_A:
  ld [hl], a

  ; now detect collision with coins and signs
  ld a, [wCursorY]
  and $F0
  swap a
  ld e, a  ; E = Y coordinate in metatiles
  ld a, [wCursorX]
  ld d, a
  ld a, [wCursorX+1]
  xor d
  and $0F  ; keep low nibble of high byte and high nibble of low byte
  xor d
  swap a
  ld d, a  ; D = X coordinate in metatiles
  ld hl, coin_pos
  .coin_sign_loop:
    ld a, [hl+]  ; fetch X coordinate
    cp d
    jr nz, .not_this_coin_or_sign
    ld a, [hl]   ; fetch Y coordinate
    and $0F      ; skip priority bits
    cp e
    jr nz, .not_this_coin_or_sign
      ld a, l
      sub low(coin_pos)
      srl a
      jr .is_over_item_a
    .not_this_coin_or_sign:
    inc hl
    ld a, l
    xor low(coin_pos + 2 * (NUM_DEFINED_COINS + NUM_DEFINED_SIGNS))
    jr nz, .coin_sign_loop

  ld a, [wCursorX]
  sub low(MINDY_X)
  ld c, a
  ld a, [wCursorX+1]
  sbc high(MINDY_X)
  ld b, a
  sbc a
  and OAMF_XFLIP
  ld [wMindyFacing], a

  ; Face cursor
  ld a, [wCursorY]
  sub MINDY_Y
  cp -24
  jr c, .notOverMindy
  ld a, MINDY_HITBOX_WIDTH/2
  add c
  ld c, a
  adc b
  sub c
  jr nz, .notOverMindy

  ld a, c
  cp MINDY_HITBOX_WIDTH
  jr nc, .notOverMindy
  ld a, PAGE_MINDY

.is_over_item_a:
  ld [wCursorItem], a
  ld hl, hNewKeys 
  bit PADB_A, [hl]
  ret z

  ; mark thing as seen
  push af
  ld hl, wSeenPages
  add l
  ld l, a
  adc h
  sub l
  ld h, a
  ld [hl], 1
  pop af
  jp textwindow_start_page

.notOverMindy:
  ret

def CURSOR_DAMPING equ 2

;;
; Divides A by 2^CURSOR_DAMPING, rounding per wGlobalSubpixel
; @return A: rounded quotient; B: quotient rounded toward 0;
; C: wGlobalSubpixel
; DEHL unchanged
divide_by_damping:
  ld b, a
  fallthrough divide_B_by_damping
divide_B_by_damping:
  ld a, [wGlobalSubpixel]
  ld c, a
  xor a
  rept CURSOR_DAMPING
    sra b
    rra
  endr
  ; BA: 1/256 pixels to add
  add c
  ld a, 0
  adc b
  ret

; Camera control ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def CURSOR_MOVE_MAX equ 8 << CURSOR_DAMPING

move_camera:
  ; calculate vertical displacement
  ld a, [wCursorY]
  sub SCRN_Y/2
  jr nc, .noYTopClip
    xor a
  .noYTopClip:
  cp MAP_COLUMN_HEIGHT_MT * 16 - SCRN_Y
  jr c, .noYBottomClip
    ld a, MAP_COLUMN_HEIGHT_MT * 16 - SCRN_Y
  .noYBottomClip:
  ld hl, wCameraY
  sub [hl]

  ; scroll by that amount
  call divide_by_damping
  add [hl]
  ld [hl], a

  ; Don't update horizontally if window is being drawn
  ld a, [wWindowProgress]
  cp TEXTWINDOW_ROWS
  ret c

  ; calculate horizontal displacement
  ld hl, wCursorX
  ld a, [hl+]
  sub SCRN_X/2
  ld c, a
  ld a, [hl]
  sbc 0
  jr nc, .noXLeftClip
    xor a
    ld c, a
  .noXLeftClip:
  ld b, a
  ld hl, wCameraX
  ld a, c
  sub [hl]
  ld e, a
  ld a, b
  inc hl
  sbc [hl]  ; AE = displacement
  dec hl

  ; clamp displacement to maximum
  jr c, .clamp_x_neg
    jr nz, .displacement_is_max_pos
    ld a, e
    cp CURSOR_MOVE_MAX
    jr c, .have_x_dist
  .displacement_is_max_pos:
    ld a, CURSOR_MOVE_MAX
    jr .have_x_dist
  .clamp_x_neg:
    inc a
    jr nz, .displacement_is_max_neg
    ld a, e
    cp -CURSOR_MOVE_MAX
    jr nc, .have_x_dist
  .displacement_is_max_neg:
    ld a, -CURSOR_MOVE_MAX
  .have_x_dist:

  ; scroll by a fraction of that amount
  call divide_by_damping
  ld c, a
  add a
  sbc a
  ld b, a  ; BC = signed displacement
  ld a, c  
  add [hl]
  ld [hl+], a
  ld a, b
  adc [hl]
  ld [hl], a

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
  ; [HL] is current left edge of camera
  ; <0 (CF=1): go left now
  ; 0: go left unless already 0
  ; 1: prepare to go left unless already 0
  ; >=MAP_VICINITY_WIDTH_MT-SCRN_X/16-1: go right unless at 240
  ;   already 256-MAP_VICINITY_WIDTH_MT
  jr c, .decode_to_left
  jr z, .decode_to_left
  cp 1
  jr nz, .no_seek_toward_left
    ; if camera near left side of vicinity, prepare for decoding to left
    ld a, [hl]
    jp map_seek_column_a
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
  .no_seek_toward_left:

  ; A is still distance in MTs from vicinity left to camera left
  cp MAP_VICINITY_WIDTH_MT-SCRN_X/16-2
  jr z, .seek_toward_right
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
  .seek_toward_right:
    ; if camera near right side of vicinity, prepare for decoding to right
    ld a, [hl]
    add MAP_VICINITY_WIDTH_MT
    ret c
    jp map_seek_column_a

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
  fallthrough blit_c_columns

;;
; Draws tile columns from vicinity to the screen.
; @param C count of tilemap columns (half vicinity columns)
; @param B first tilemap column to draw (0-31)
blit_c_columns:
  .drawloop:
    push bc
    ld a, b
    call blit_one_col_new
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
      add low(metatiles_chains)
      ld e, a
      adc high(metatiles_chains)
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

; Test level data ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; stage 1

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
def MAP_WIDTH_MT equ (@-level1Bitmap)/2

level1Contents:
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_GROUND
db MT_CLOUD, MT_SIGN
db MT_CLOUD, MT_GROUND

db MT_CLOUD, MT_GROUND
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
db MT_BUSH
db MT_BUSH
db MT_GROUND
db MT_GROUND
db MT_FLOWER3

db MT_GROUND
db MT_LADDER, MT_GROUND
db MT_GROUND_0HT, MT_GROUND
db MT_BUSH, MT_GROUND_0HT, MT_GROUND
db MT_BUSH, MT_GROUND_0HT, MT_GROUND
db MT_SIGN, MT_GROUND_0HT, MT_GROUND
db MT_BRIDGE_RAIL, MT_BRIDGE_BRACE_L, MT_WARNING_SIGN
db MT_BRIDGE_RAIL, MT_GROUND

db MT_BRIDGE_RAIL
db MT_BRIDGE_RAIL, MT_BRIDGE_BRACE_R
db MT_GROUND
db MT_TALL_FLOWER
db MT_BUSH, MT_TREE, MT_GROUND, MT_CAVE, MT_GROUND
db MT_BUSH, MT_TREE, MT_GROUND, MT_CAVE, MT_GROUND
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

coin_pos: 
  db 15, 9
  db 24, 8
  db 27, 5|$80  ; coin half behind bush
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
static_tiles:
  dw $9000
  db 80
  incbin "obj/gb/parkmetatiles.2b.pb16"
  dw $8000 + 16 * COINCELS_BASE_TILE
  db 5
  incbin "obj/gb/coincels.2b.pb16"
  dw $8000 + 16 * CURSOR_TILE_NO_MATCH
  db 4
  incbin "obj/gb/cursor.2b.pb16"

; Static sprite drawing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

def COINS_ATTR equ $11  ; no flip, DMG and GBC palette 1

section "draw_objs", ROM0
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
      ld a, [bc]
      and $80  ; priority
      or COINS_ATTR
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

draw_cursor:
  ld hl, wOAMUsed
  ld l, [hl]
  ld a, [wCameraY]
  ld b, a
  ld a, [wCursorY]
  sub b
  add 16-1
  ld [hl+], a
  ld a, [wCameraX]
  ld b, a
  ld a, [wCursorX]
  sub b
  add 8-1
  ld [hl+], a
  ld a, [wCursorItem]
  rlca
  and $01
  xor CURSOR_TILE_NO_MATCH|1
  ld [hl+], a
  rrca
  sbc a
  and $11  ; attribute
  ld [hl+], a
  ld a, l
  ld [wOAMUsed], a
  ret

; Title screen ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "title", ROMX,BANK[1]

show_title:
  call lcd_off
  ld hl, title_2b
  ld de, $8800
  call memcpy_pascal16
  ld de, _SCRN0
  call load_full_nam

  xor a
  ldh [rIF], a
  ldh [rSCX], a
  ldh [rSCY], a
  ld a, IEF_VBLANK
  ldh [rIE], a
  ei
  ld a, %11100100
  call set_bgp
  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_BG9800|LCDCF_BG8800
  ldh [rLCDC], a

  .loop:
    halt
    call read_pad
    ldh a, [hNewKeys]
    and PADF_START|PADF_A
    jr z, .loop
  ret

title_2b:
  dw .end-.start
.start:
  incbin "obj/gb/title.2b"
.end:
  incbin "obj/gb/title.nam"
