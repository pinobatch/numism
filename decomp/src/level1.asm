include "src/hardware.inc"
include "src/global.inc"

; the width of the area that can affect autotiling of onscreen tiles
def MAP_VICINITY_WIDTH_MT equ 16
def MAP_COLUMN_HEIGHT_MT equ 16

def COINCELS_BASE_TILE equ $7B

; This number is added to wGlobalSubpixel every frame.  It must be
; odd and should be close to 256 divided by a highly irrational
; number (lots of small terms in continued fraction representation)
; to mask repetition.  Here we use 256 divided by the golden ratio,
; which is the most irrational number (see numberphile video).
def GLOBAL_SUBPIXEL_ADD equ 159
def STARTING_CURSOR_Y equ 64
def STARTING_CURSOR_X equ 64

def WINDOW_ROWS equ 5
def NUM_HIDDEN_OBJS equ 10
def PAGE_MINDY equ 9
def PAGE_FOUND_THEM_ALL equ 10
def PAGE_INSTRUCTIONS equ 11

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

wGlobalSubpixel: ds 1
wCursorY: ds 1
wCursorX: ds 2
wCursorYAdd: ds 1
wCursorXAdd: ds 1
wWindowProgress: ds 1
wWindowTextPtr: ds 2

wCursorItem: ds 1
wMindyLoadedCel: ds 1
wMindyDisplayCelBase: ds 1
wWindowLoadedPage: ds 1
wMindyFacing: ds 1

section "seenpages", WRAM0
wSeenPages: ds NUM_HIDDEN_OBJS

def TEST_REWIND_COLUMN equ 4

section "stack", WRAM0, ALIGN[1]
wStackTop: ds 64
wStackStart:

section "main", ROM0

main:
  call show_title
  call lcd_off
  ld hl, level1chr_2b
  ld de, $9000
  call memcpy_pascal16
  ld hl, coincels_2b
  ld de, $8000 + 16 * COINCELS_BASE_TILE
  call memcpy_pascal16
  ld hl, cursor_2b
  ld de, $8000 + 16 * CURSOR_TILE_NO_MATCH
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

  ld [wMindyDisplayCelBase], a
  dec a
  ld [wMindyLoadedCel], a
  ld [wWindowLoadedPage], a

  call init_window
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

.forever:
  ld hl, wGlobalSubpixel
  ld a, GLOBAL_SUBPIXEL_ADD
  add [hl]
  ld [hl], a
  call read_pad
  call move_cursor
  ld a, %11100111
  ldh [rBGP], a
  call move_camera
  ld a, %11100100
  ldh [rBGP], a
  call update_window
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
  ldh [rBGP], a
  ldh [rOBP1], a
  ld a, [hVblanks]
  rra
  sbc a
  and %00010000
  or  %10000000
  ldh [rOBP0], a
  ld a, [wCameraX]
  ldh [rSCX], a
  ld a, [wCameraY]
  ldh [rSCY], a
  ld a, [wWindowProgress]
  sub WINDOW_ROWS
  add a  ; CF true to hide window
  sbc a
  or SCRN_Y-WINDOW_ROWS * 8
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
    call start_window_page_a
    jr .no_cursor_movement
  .not_won_msg:
    ld a, $FF
    ld [wWindowProgress], a
  .no_cursor_movement:

  ldh a, [hNewKeys]
  bit PADB_SELECT, a
  jr z, .notSelect
    ld a, [wMindyLoadedCel]
    inc a
    cp MINDY_NUM_FRAMES
    jr c, .noFrameWrap
      xor a
    .noFrameWrap:
    call mindy_set_cel_A
  .notSelect:

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
  jp start_window_page_a

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
  cp WINDOW_ROWS
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
  ; Calculate addresses in tilemap and metatile map
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
    inc c
    bit 2, d  ; once D reaches $9C00 we're done
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
def MAP_WIDTH_MT equ (@-level1Bitmap)/2

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
cursor_2b:
  dw .end-.start
.start:
  incbin "obj/gb/cursor.2b"
.end:

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

; Drawing Mindy ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "Mindy", ROMX,BANK[1]

def MINDY_MAX_TILES_PER_CEL equ 9
def MINDY_EST_LINES_PER_TILE equ 5

mindy_set_cel_A:
  ; don't load it if it's already loaded
  ld hl, wMindyLoadedCel
  cp [hl]
  ret z

  ld [hl], a
  add a
  add low(Mindy_mspr)
  ld l, a
  adc high(Mindy_mspr)
  sub l
  ld h, a
  ld a, [hl+]
  ld d, [hl]
  ld e, a
  ; DE points at a cel definition:
  ; number of distinct tiles, tile IDs, and horizontal strips
  ld a, [de]
  inc de
  or a
  ret z  ; blank cel
  ld c, a  ; C: tile count

  ; Find the destination address in CHR RAM
  ld a, [wMindyDisplayCelBase]
  cp 1
  sbc a
  and MINDY_MAX_TILES_PER_CEL
  ld [wMindyDisplayCelBase], a
  ld h, $8000 >> 12
  ld l, a
  rept 4
    add hl, hl
  endr

  .tileloop:
    ; Grab one tile ID from the cel definition
    ld a, [de]
    inc de
    push de

    ; Calculate ROM address of this tile
    ld d, 0
    rept 4
      add a
      rl d
    endr
    add low(Mindy_chr)
    ld e, a
    ld a, d
    adc high(Mindy_chr)
    ld d, a

    ; Copy it
    ld b, 16/4
    call hblankcopy
    pop de
    dec c
    jr nz, .tileloop
  ret

def MINDY_X equ 288
def MINDY_Y equ 144
def MINDY_NUM_FRAMES equ 41

mindy_draw_current_cel:
  ld hl, wCameraY
  ld a, low(MINDY_Y)
  sub [hl]
  ldh [draw_metasprite.hYLo], a
  ld a, high(MINDY_Y)
  sbc 0
  ldh [draw_metasprite.hYHi], a

  ld hl, wCameraX
  ld a, low(MINDY_X)
  sub [hl]
  inc hl
  ldh [draw_metasprite.hXLo], a
  ld a, high(MINDY_X)
  sbc [hl]
  ldh [draw_metasprite.hXHi], a
  ld a, [wMindyFacing]
  ldh [draw_metasprite.hAttr], a
  ld a, [wMindyDisplayCelBase]
  ld [draw_metasprite.hBaseTile], a

  ; lookup the metatile
  ld a, [wMindyLoadedCel]
  add a
  add low(Mindy_mspr)
  ld l, a
  adc high(Mindy_mspr)
  sub l
  ld h, a  ; HL: pointer to pointer to cel
  ld a, [hl+]
  ld h, [hl]
  ld l, a  ; HL: pointer to cel's tile count
  ld a, [hl+]
  add l
  ld l, a
  adc h
  sub l
  ld h, a  ; HL: pointer to cel's rectangles
  jp draw_metasprite

def TMARGIN equ 16
def LMARGIN equ 8
def SPRITEHT equ 8  ; or 16?
def SPRITEWID equ 8

section "metasprite", ROM0

;;
; Draws to shadow OAM a list of sprites forming one cel.
;
; The cel data is of the form
; (Y, X, attributes, tile+)+, $00
; where:
; Y is excess-128 offset of sprite top down from hotspot (128 is center)
; X is excess-128 offset to right of hotspot (128 is center)
; attributes is a bitfield, where bits 4-0 go to OAM attribute 3
; and 7-5 are the number of tiles to follow minus 1
; 7654 3210
; |||| |+++- GBC palette ID
; |||| +---- GBC bank ID
; |||+------ DMG palette ID
; +++------- Length of strip (0: 1 sprite/8 pixels; 7: 8 sprites/64 pixels)
; tile bits 7-6 are flip, and 5-0 are data
; 7654 3210
; ||++-++++- offset from hmsprBaseTile
; |+-------- Flip this sprite horizontally
; +--------- Flip this tile vertically
; and "+" means something is repeated 1 or more times
;
; @param hYHi, hYLo 16-bit Y coordinate of hotspot
; @param hXHi, hXLo 16-bit Y coordinate of hotspot
; @param hAttr palette and horizontal flip
; @param hBaseTile index of this sprite sheet in VRAM
; @param HL pointer to cel data
; Uses 8 bytes of locals for arguments and 4 bytes for scratch
draw_metasprite::
  ; args
  local hYLo
  local hYHi
  local hXLo
  local hXHi
  local hAttr
  local hSheetID
  local hFrame
  local hBaseTile
  ; internal
  local hXAdd
  local hStripY
  local hStripXLo
  local hStripXHi

  ldh a,[.hAttr]
  ld c,a  ; C = flip flags

  ; Correct coordinates for offset binary representation.
  ; Not correcting for Y flip until a Y flip is needed in a game.
  ldh a,[.hYLo]
  sub 128-TMARGIN
  ldh [.hYLo],a
  ldh a,[.hYHi]
  sbc 0
  ldh [.hYHi],a

  ; Convert X coordintes and set increase direction for X flip
  ld b,128-LMARGIN
  ld a,SPRITEWID
  bit OAMB_XFLIP,c
  jr z,.noxcoordflipcorrect
    ld b,127+SPRITEWID-LMARGIN
    ld a,-SPRITEWID
  .noxcoordflipcorrect:
  ldh [.hXAdd],a
  ldh a,[.hXLo]
  sub b
  ldh [.hXLo],a
  ldh a,[.hXHi]
  sbc 0
  ldh [.hXHi],a

  ; Load destination address
  ld de, wOAMUsed
  ld a, [de]
  ld e, a
  .rowloop:
    ; Invariants here:
    ; DE is multiple of 4 and within shadow OAM
    ; HL at start of sprite strip
    ; C equals [.hAttr], not modified by a strip

    ; Load Y strip offset
    ld a,[hl+]
    or a  ; Y=0 (that is, -128) terminates cel
    ret z
    bit OAMB_YFLIP,c
    jr z,.noystripflipcorrect
      cpl
    .noystripflipcorrect:
    ld b,a
    ldh a,[.hYLo]
    add b
    ld b,a
    ldh a,[.hYHi]
    adc 0
    jr nz,.strip_below_screen
    ld a,b
    cp TMARGIN+1-SPRITEHT
    jr c,.strip_below_screen
    cp SCRN_Y+TMARGIN
    jr c,.strip_within_y_range
    .strip_below_screen:
      inc hl  ; skip X position
      ld a,[hl+]  ; load length and attributes
      and $E0  ; strip PVH bits contain width-1
      rlca
      rlca
      rlca
      inc a
      add l
      ld l,a
      jr nc,.rowloop
      inc h
      jr .rowloop
    .strip_within_y_range:
    ldh [.hStripY],a

    ; Load X strip offset
    ld a,[hl+]
    bit OAMB_XFLIP,c
    jr z,.noxstripflipcorrect
      cpl
    .noxstripflipcorrect:
    ld b,a
    ldh a,[.hXLo]
    add b
    ldh [.hStripXLo],a
    ldh a,[.hXHi]
    adc 0
    ldh [.hStripXHi],a

    ; Third byte of strip is palette (bits 4-0) and length (bits 7-5)
    ld a,[hl]
    and $1F
    xor c
    ld c,a
    ld a,[hl+]
    and $E0  ; strip PVH bits contain width-1
    rlca
    rlca
    rlca
    inc a
    ld b,a

    ; Copy sprites to OAM
    .spriteloop:
      push bc  ; sprite count and strip attribute
      ldh a,[.hStripY]
      ld [de],a

      ; Only resulting X locations in 1-167 are in range
      ldh a,[.hStripXHi]
      or a
      jr nz,.skip_one_tile
      ldh a,[.hStripXLo]
      or a
      jr z,.skip_one_tile
      cp SCRN_X+LMARGIN
      jr nc,.skip_one_tile

      ; We're in range, and Y is already written.
      ; Acknowledge writing Y, and write X, tile, and attribute
      inc e
      ld [de],a
      inc e
      ld a,[hl]
      and $3F
      ld b,a
      ldh a,[.hBaseTile]
      add b
      ld [de],a
      inc e
      ld a,[hl]
      and $C0  ; combine with tile flip attribute
      rrca
      xor c
      ld [de],a
      inc e

    .skip_one_tile:
      ldh a,[.hXAdd]
      ld b,a
      ldh a,[.hStripXLo]
      add b
      ldh [.hStripXLo],a
      ldh a,[.hStripXHi]
      adc 0
      bit 7,b
      jr z,.anoneg
        dec a
      .anoneg:
      ldh [.hStripXHi],a
      pop bc
      inc hl
      dec b
      jr nz,.spriteloop
    ld a, e
    ld [wOAMUsed], a
    ldh a,[.hAttr]
    ld c,a
    jp .rowloop

Mindy_mspr:
  include "obj/gb/Mindy.asm"

section "Mindy_chr", ROMX, bank[1], align[4]
Mindy_chr:
  incbin "obj/gb/Mindy.2b"

; Drawing the window ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section "txt_window_code", ROM0

init_window:
  ; clear pattern table
  ld hl, $9000-WINDOW_ROWS*$100
  xor a
  ld c, a
  rept WINDOW_ROWS
    rst memset_tiny
  endr

  ; set up nametable
  ld hl, $9C00
  ld b, $05
  .rowloop:
    xor a
    ld [hl+], a
    ld [hl+], a
    ld c, 16
    ld a, c
    sub b  ; window uses tiles $B0-$FF
    swap a
    call memset_inc
    ld c, 14
    xor a
    call memset_tiny
    dec b
    jr nz, .rowloop

  ld a, PAGE_INSTRUCTIONS
  fallthrough start_window_page_a

;;
; Draws page A
start_window_page_a:
  ; If the page is already loaded and showing,
  ; don't try to load it again
  ld hl, wWindowLoadedPage
  cp [hl]
  ld [hl], a
  jr nz, .not_already_loaded
    ld a, [wWindowProgress]
    cp WINDOW_ROWS
    ret z
  .not_already_loaded:
  ld a, [hl]  ; restore loaded page
  add a
  ld hl, window_txts
  add l
  ld l, a
  adc h
  sub l
  ld h, a
  ld a, [hl+]
  ld [wWindowTextPtr], a
  ld a, [hl+]
  ld [wWindowTextPtr+1], a
  xor a
  ld [wWindowProgress], a
  ret

update_window:
  ; run only if a window update is requested and the screen is on
  ld a, [wWindowProgress]
  cp WINDOW_ROWS
  ret nc
  ldh a, [rLCDC]
  add a
  ret nc

  call vwfClearBuf
  ld hl, wWindowTextPtr
  ld a, [hl+]
  ld h, [hl]
  ld l, a
  ld b, 0
  call vwfPuts
  ; skip newline; don't skip NUL terminator
  ld a, [hl]
  or a
  jr z, .no_skip_newline
    inc hl
  .no_skip_newline:
  ld a, l
  ld [wWindowTextPtr], a
  ld a, h
  ld [wWindowTextPtr+1], a
  ld hl, wWindowProgress
  ld a, [hl]
  inc [hl]
  add $8B
  ld h, a
  ld l, 1
  ld c, 16
  jp vwfPutBufHBlank


window_txts:
  dw coin1_msg, coin2_msg, coin3_msg, coin4_msg, coin5_msg
  dw sign1_msg, sign2_msg, sign3_msg, sign4_msg, Mindy_msg
  dw win_msg, instructions_msg

def LF equ $0A
coin1_msg:
  db "800 Rupees",LF
  db "Currency of Hyrule and India",LF
  db "(That's about $10)",0
coin2_msg:
  db "800 Pokedollars",LF
  db "Currency of Kanto",LF
  db "and the Russia",LF
  db "(That's about $10)",0
coin3_msg:
  db "1400 Bells",LF
  db "Currency of territories",LF
  db "controlled by the Nook family",LF
  db "(That's about $10)",0
coin4_msg:
  db "5 Eurodollars",LF
  db "Currency of Night City and",LF
  db "banks outside the USA",LF
  db "Invented by USSR in 1956",LF
  db "Banned in USSR in Cyberpunk",0
coin5_msg:
  db "A roll of quarters",LF
  db "Currency of Toy Town",LF
  db "(That's about $10)",0
sign1_msg:
  db "DANGER",LF
  db "BRIDGE OUT AHEAD",0
sign2_msg:
  db "BEWARE OF FUNNY MONEY",LF
  db "If something looks off,",LF
  db "take no cash.",0
sign3_msg:
  db "NO",LF
  db "JUMPING",0
sign4_msg:
  db "EVENT CALENDAR",LF
  db "May 28-June 4:",LF
  db "  Summer Games Done Quick",LF
  db "June 10: Yogic Flying Lesson",LF
  db "June 16-18: Flea Market",0
Mindy_msg:
  db "Hi! I'm Mindy!",LF
  db "I'm looking for money so I",LF
  db "can buy Game Boy games",LF
  db "like Esprit and Star Anise.",0
win_msg:
  db "You found them all!",LF
  db "Thanks for playing my entry",LF
  db "to Games Made QVIIck.",LF
  db "- Pino",0
instructions_msg:
  db "Control Pad moves cursor.",LF
  db "Cursor is solid when over",LF
  db "something; press the",LF
  db "A Button to view it.",LF
  db "View all 10 things to win.",0

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
  ldh [rBGP], a
  ld a, LCDCF_ON|LCDCF_BGON|LCDCF_BG9800|LCDCF_BG8800
  ldh [rLCDC], a

  .loop:
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

load_full_nam::
  ld bc,256*20+18
  fallthrough load_nam
;;
; Copies a B column by C row tilemap from HL to screen at DE.
load_nam::
  push bc
  push de
  .byteloop:
    ld a,[hl+]
    ld [de],a
    inc de
    dec b
    jr nz,.byteloop

  ; Move to next screen row
  pop de
  ld a,32
  add e
  ld e,a
  jr nc,.no_inc_d
    inc d
  .no_inc_d:

  ; Restore width; do more rows remain?
  pop bc
  dec c
  jr nz,load_nam
  ret

section "memset_tiny",ROM0[$08]
;;
; Writes C bytes of value A starting at HL.
memset_tiny::
  ld [hl+],a
  dec c
  jr nz,memset_tiny
  ret

section "memset_inc",ROM0
;;
; Writes C bytes of value A, A+1, ..., A+C-1 starting at HL.
memset_inc::
  ld [hl+],a
  inc a
  dec c
  jr nz,memset_inc
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
  fallthrough memcpy

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

section "hblankcopy", ROM0
;;
; Performs an hblank copy that isn't a stack copy.
; Copies 4*B bytes from DE to HL (opposite of standard memcpy)
; at 4 bytes per line.  C unchanged
hblankcopy:
  ldh a, [rLCDC]
  add a
  jr nc, .unbusy_done
  ; wait for mode not 0
.unbusy:
  ldh a, [rSTAT]
  and $03
  jr z, .unbusy
.unbusy_done:

  push bc
  ; then wait for mode 0 or 1
  ld a, [de]
  ld c, a
  inc e
  ld a, [de]
  ld b, a
  inc e
.busy:
  ldh a, [rSTAT]
  and $02
  jr nz, .busy  ; spin wait can take up to 12 cycles
  ld a, c      ; 1
  ld [hl+], a  ; 2
  ld a, b      ; 1
  ld [hl+], a  ; 2
  ld a, [de]   ; 2
  ld [hl+], a  ; 2
  inc e        ; 1
  ld a, [de]   ; 2
  ld [hl+], a  ; 2
  inc de
  pop bc
  dec b
  jr nz, hblankcopy
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
