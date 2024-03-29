include "src/hardware.inc"
include "src/global.inc"

section "autotiler", ROM0
;;
; Draws a half-column in vicinity to the screen
; @param A column to draw (0-31)
blit_one_col_new::
  local hThisColumnXAddr
  local hAdjacentColumnXAddr
  local hMtDefsLo
  local hMtDefsHi

  ; register variables:
  ; DE = VRAM destination address
  ; C = vicinity row address

  ; Find the column being drawn
  and SCRN_VX_B-1
  ld e, a
  ld d, high(_SCRN0)
  rra
  and MAP_VICINITY_WIDTH_MT-1
  add high(wMapVicinity)
  ldh [.hThisColumnXAddr], a

  ; Find the adjacent column for autotiling comparison.
  ; If the left half of the leftmost column is being drawn,
  ; use self.  Otherwise, use the column to the left.
  ld a, [wMapVicinityLeft]
  or e 
  jr z, .haveAdjacentColumnWrappedX
    ld a, e
    rra
    ; decrease by 1 if NC or increase by 1 if C
    dec a
    jr nc, .adjacentColumnIsPrevious
      add 2
    .adjacentColumnIsPrevious:
    and MAP_VICINITY_WIDTH_MT-1
  .haveAdjacentColumnWrappedX:
  add high(wMapVicinity)
  ldh [.hAdjacentColumnXAddr], a

  ; Choose definitions of the left or right half of a metatile
  ; in order:
  ; $00 top left attribute, edge
  ; $01 bottom left attribute, edge
  ; $02 top left tile number, edge
  ; $03 bottom left tile number, edge
  ; $04 top left attribute, interior
  ; $05 bottom left attribute, interior
  ; $06 top left tile number, interior
  ; $07 bottom left tile number, interior
  ; $08 top right attribute, edge
  ; $09 bottom right attribute, edge
  ; $0A top right tile number, edge
  ; $0B bottom right tile number, edge
  ; $0C top right attribute, interior
  ; $0D bottom right attribute, interior
  ; $0E top right tile number, interior
  ; $0F bottom right tile number, interior
  ld a, e
  rra
  sbc a  ; 00: left, FF: right
  and $08
  add low(metatiles_defs)
  ldh [.hMtDefsLo], a
  ld a, 0
  adc high(metatiles_defs)
  ldh [.hMtDefsHi], a

  ld c, low(wMapVicinity)
  .blkloop:
    ; look up metatile number in vicinity
    ldh a, [.hThisColumnXAddr]
    ld b, a
    ld a, [bc]
    ld l, a

    ; Choose interior or edge variant of this metatile
    ldh a, [.hAdjacentColumnXAddr]
    ld b, a
    ld a, [bc]
    xor l       ; A=$00: interior; nonzero: edge

    ; Translate metatile number to offset from metatile table start
    ld h, 0
    add hl, hl  ; start at whatever left or right half is baked
                ; into hMtDefsLo
    cp 1        ; CF=1: interior; CF=0: edge
    rl l
    rl h
    add hl, hl  ; start at top (vs. bottom)
    add hl, hl  ; start at attribute (vs. tile)

    ; Translate the offset into an address
    ldh a, [.hMtDefsLo]
    add l
    ld l, a
    ldh a, [.hMtDefsHi]
    adc h
    ld h, a

    ld a, 1
    ldh [rVBK], a  ; prepare to write attribute

    ; wait for mode 0 or 1
    .stat01loop_attr:
      ldh a, [rSTAT]
      and STATF_BUSY
      jr nz, .stat01loop_attr

    ; write attributes (10 cycles hblank open)
    ld a, [hl+]
    ld [de], a
    set 5, e
    ld a, [hl+]
    ld [de], a
    res 5, e
    inc c          ; go to next row of vicinity
    xor a
    ldh [rVBK], a  ; prepare to write tile number

    ; wait for mode 0 or 1
    .stat01loop_tilenum:
      ldh a, [rSTAT]
      and STATF_BUSY
      jr nz, .stat01loop_tilenum

    ; write tile numbers
    ld a, [hl+]
    ld [de], a
    set 5, e
    ld a, [hl+]
    ld [de], a

    ; move destination address to next row
    ld a, e
    add SCRN_VX_B
    ld e, a
    adc d
    sub e
    ld d, a
    cp high(_SCRN0 + MAP_COLUMN_HEIGHT_MT * MT_HEIGHT_CHARS * SCRN_VY_B)
    jr c, .blkloop
  ret
