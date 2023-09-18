include "src/hardware.inc"
include "src/global.inc"

def MINDY_MAX_TILES_PER_CEL equ 9
def MINDY_EST_LINES_PER_TILE equ 5

def MINDY_X equ 288
def MINDY_Y equ 144
def MINDY_NUM_FRAMES equ 41
export MINDY_X, MINDY_Y

section "Mindy_state", WRAM0
wMindyLoadedCel: ds 1
wMindyDisplayCelBase: ds 1
wMindyFacing:: ds 1

section "Mindy", ROMX,BANK[1]

mindy_init::
  xor a
  ld [wMindyDisplayCelBase], a
  dec a
  ld [wMindyLoadedCel], a
  ret

mindy_set_next_cel::
  ld a, [wMindyLoadedCel]
  inc a
  cp MINDY_NUM_FRAMES
  jr c, .noFrameWrap
    xor a
  .noFrameWrap:
  fallthrough mindy_set_cel_A

mindy_set_cel_A::
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

mindy_draw_current_cel::
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
