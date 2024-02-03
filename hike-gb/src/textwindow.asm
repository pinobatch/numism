include "src/hardware.inc"
include "src/global.inc"

section "textwindow_state", WRAM0
wWindowLoadedPage: ds 1
wWindowProgress::  ds 1  ; count of lines of text already loaded
wWindowTextPtr:    ds 2

section "textwindow", ROM0

textwindow_init::
  ; clear pattern table
  ld hl, $9000-TEXTWINDOW_ROWS*$100
  xor a
  ld c, a
  rept TEXTWINDOW_ROWS
    rst memset_tiny
  endr
  dec a
  ld [wWindowLoadedPage], a

  ; set up nametable
  ld hl, $9C00
  ld b, TEXTWINDOW_ROWS
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
  fallthrough textwindow_start_page

;;
; Draws page A
textwindow_start_page::
  ; If the page is already loaded and showing,
  ; don't try to load it again
  ld hl, wWindowLoadedPage
  cp [hl]
  ld [hl], a
  jr nz, .not_already_loaded
    ld a, [wWindowProgress]
    cp TEXTWINDOW_ROWS
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

textwindow_update::
  ; run only if a window update is requested and the screen is on
  ld a, [wWindowProgress]
  cp TEXTWINDOW_ROWS
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

section "window_txts", ROMX, BANK[1]

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
